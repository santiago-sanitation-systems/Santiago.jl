# -----------
# massflow

using LinearAlgebra
using Statistics
using Distributions: Dirichlet
using NamedArrays
using SparseArrays
using Random: AbstractRNG, GLOBAL_RNG, MersenneTwister
import Future
import ProgressMeter

export massflow
export lost
export recovered
export entered
export recovery_ratio
export massflow_summary, massflow_summary!, massflow_summary_parallel!
export scale_massflows, scale_massflows!
export issource
export issink

const MassDict = Dict{Tech, NamedArray{Float64}}

issource(t::T) where T <: AbstractTech = length(t.inputs) == 0
issink(t::T) where T <: AbstractTech = length(t.outputs) == 0


"""
    $TYPEDSIGNATURES

Compute massflows of a system. Optionally with Monte Carlo (MC) simulation.

## Arguments:
- `M_in`: a dictionary containing for each source the inflows of each substance.
- `MC`: if false, the expected values of the Dirichlet distribution is used as transfer.
   coefficients. Else, the transfer coefficients are sampled from a Dirichlet distribution.
- `scale_reliability`: factor to scale the `transC_reliability` of all `Techs`.
- `rng`: optional, a random generator. This is only needed for multi-threading to obtain thread-safety.
"""
function massflow(sys::System, M_in::Dict{String, Dict{String, T}};
                  MC::Bool=false, scale_reliability::Real=1.0,
                  rng::AbstractRNG=GLOBAL_RNG) where T <: Real

    # --- calculate flows
    flow_mats = Dict{String, AbstractArray}()
    M_out = MassDict()
    Ps = Dict{String, AbstractArray}()

    for substance in SUBSTANCE_NAMES

        # -- derive (random) adjacent matrix
        Pmean, rel_vect = get_adj_mat(sys, substance)

        if MC
            P = sample_P(Pmean, rel_vect, rng)
        else
            P = Pmean
        end
        Ps[substance] = P

        # -- calulate flows
        technames = collect(keys(Pmean.dicts[1]))
        m_inputs = NamedArray(zeros(size(P,1)), (technames, ))

        for name in technames
            if haskey(M_in, name)
                m_inputs[name] = M_in[name][substance]
            end
        end

        flow_mats[substance] = calc_massflows(P, m_inputs)

    end

    # --- rearrange results

    for t in sys.techs

        outprod_names = ["$(p.name)" for p in t.outputs]
        if issink(t)
            cnames = ["recovered", "airloss", "soilloss", "waterloss"]
        else
            cnames = vcat(outprod_names, ["airloss", "soilloss", "waterloss"])
        end
        masses = NamedArray(zeros(NSUBSTANCE, length(cnames)) .- 1,
                            (SUBSTANCE_NAMES, cnames),
                            ("substance", "product"))

        for substance in SUBSTANCE_NAMES

            flow = flow_mats[substance]
            P = Ps[substance]

            for prod in outprod_names
                ouput_con = collect(filter(c -> c[1]==Product(prod) && c[2] == t, sys.connections))[1]

                prod_tmp = Product(replace(prod, "transported" => ""))

                if haskey(t.transC[substance], prod_tmp)
                    tc = t.transC[substance][prod_tmp]
                else
                    tc = t.transC[substance][Product("x")]
                end

                masses[substance, prod] = flow[t.name, ouput_con[3].name] *
                    tc / P[t.name, ouput_con[3].name]
            end

            for loss in ["airloss", "soilloss", "waterloss"]
                masses[substance, loss] =flow[t.name, "$(t.name)_$loss"]
            end

            if issink(t)
                masses[substance, "recovered"] = flow[t.name, "$(t.name)_recovered"]
            end

        end
        M_out[t] = masses
    end

    return M_out

end


function get_adj_mat(sys::System, substance::String)

    # -- build matrix
    technames = getfield.(collect(sys.techs), :name)
    lossnames = vcat([["$(n)_airloss", "$(n)_soilloss", "$(n)_waterloss"] for n in technames]...)
    sinkrecoverd = ["$(s.name)_recovered" for s in sys.techs if issink(s)]
    Pnames = vcat(technames, lossnames, sinkrecoverd)
    P = NamedArray(zeros(length(Pnames), length(Pnames)), (Pnames, Pnames), ("from", "to"))

    # fill in transfer coefficients
    for c in sys.connections
        prod, from_tech, to_tech = c
        # transC are the same for transported or non-transported products
        prod_tmp = Product(replace(String(prod.name), "transported" => ""))

        if haskey(from_tech.transC[substance], prod_tmp)
            tc = from_tech.transC[substance][prod_tmp]
        else
            tc = from_tech.transC[substance][Product("x")]
        end
        P[from_tech.name, to_tech.name] += tc
    end

    # add all losses
    for t in sys.techs
        P[t.name, t.name * "_airloss"] = t.transC[substance][Product("airloss")]
        P[t.name, t.name * "_soilloss"] = t.transC[substance][Product("soilloss")]
        P[t.name, t.name * "_waterloss"] = t.transC[substance][Product("waterloss")]
    end

    # add 'recovered' for sinks
    for t in filter(issink, sys.techs)
        P[t.name, t.name * "_recovered"] = t.transC[substance][Product("recovered")]
    end

    # compile transC_reliability vector
    rel_vect = NamedArray(zeros(length(Pnames)), (Pnames, ))
    for t in sys.techs
        rel_vect[t.name] = t.transC_reliability[substance]
    end

    return P, rel_vect
end



# Sample a random adjacent matrix. Each row is Dirichlet distributed
function sample_P(P::AbstractArray, transC_reliability::AbstractArray, rng::AbstractRNG)

    P2 = 0.0*P
    for i in 1:size(P,1)
        alpha = Float64[]
        i_zero = fill(true, size(P,2))
        for j in 1:size(P,2)
            if P[i,j] > 0.0
                i_zero[j] = false
                push!(alpha, P[i,j]*transC_reliability[i])
            end
        end
        if sum(i_zero) != size(P,2)
            P2[i,.!i_zero] = rand(rng, Dirichlet(alpha))
        end
    end
    P2
end



function calc_massflows(P::AbstractArray, inp::AbstractVector)

    size(P,1) == size(P,2) || error("'P' must be a square matrix!")
    size(P,1) == length(inp) || error("'inp' must have $size(P,1) elements")

    names = P.dicts[1]
    P = P.array
    inp = inp.array

    # same as m = inp*P * inv(I - P), but numerically better
    b = P'*inp
    A = (I - P)'
    m = sparse(A) \ b

    flows = similar(P, Float64)
    @inbounds for i=1:size(P,1), j=1:size(P,1)
        flows[i,j] = (m[i]+inp[i])*P[i,j]
    end

    return NamedArray(flows, (names, names), ("from", "to"))

end


# -----------
# summary functions

function lost(M_out::MassDict)
    sum(m[:,(end-2):end] for (t,m) in M_out)
end


function recovered(M_out::MassDict)
    sum(m[:,1:end-3] for (t,m) in M_out if issink(t))
end


function entered(M_in::Dict, sys::System)
    ent = NamedArray(zeros(NSUBSTANCE, 1), (SUBSTANCE_NAMES, ["entered"]), (:substance, :mass))
    in_dicts = [m for (t,m) in M_in if t in getfield.(collect(sys.techs), :name)]
    for substance in SUBSTANCE_NAMES
        ent[substance, "entered"] = sum(get.(in_dicts, substance, 0))
    end
    return ent
end


function recovery_ratio(M_out::MassDict, M_in::Dict, sys::System)
    mass_in = entered(M_in, sys)
    f = recovered(M_out) ./ mass_in
    f[mass_in .== 0.0] .= 1.0  # define: 0/0 := 1.0
    setnames!(f, "ratio", 2, 1)
    return(f)
end


function functional_group_losses(M_out::MassDict, M_in::Dict, sys::System)

    functional_groups = [:U, :S, :C, :T, :D]
    losses = NamedArray(zeros(NSUBSTANCE, 1 + length(functional_groups)*3),
                        (SUBSTANCE_NAMES,
                        vcat("entered", [["$(f)_airloss", "$(f)_soilloss", "$(f)_waterloss"] for f in functional_groups]...)),
                        )

    losses[:,"entered"] = entered(M_in, sys)

    for f in functional_groups
        loss = zeros(4, 3)
        t_fg = filter(t -> t.functional_group == f, sys.techs)
        for t in t_fg
            loss += M_out[t][:,(end-2):end]
        end

        losses[:,["$(f)_airloss", "$(f)_soilloss", "$(f)_waterloss"]] = loss
    end
    losses
end


"""
    $TYPEDSIGNATURES

Performs Monte Carlo massflow calculations and provides the summary statistics of a the main results.

## Arguments:
- `M_in`: a dictionary containing for each source the inflows of each substance.
- `MC`: if false, the expected values of the Dirichlet distribution is used as transfer
   coefficients. Else, the transfer coefficients are sampled from a Dirichlet distribution.
- `n`: number of Monte Carlo simulations. Ignored if `MC=false`.
- `scale_reliability`: factor to scale the `transC_reliability` of all `Techs`.
- `techflows`: if true, the flows of the individual techs are summarized
- `rng`: optional, a random generator. This is only needed for multi-threading to obtain thread-safety.

"""
function massflow_summary(sys::System, M_in::Dict; MC::Bool=true, n::Int=100, techflows::Bool=false,
                          scale_reliability::Real=1.0, rng::AbstractRNG=GLOBAL_RNG)


    # -- convert M_in

    sources = [t for t in sys.techs if issource(t)]
    for ts in sources
        haskey(M_in, ts.name) || error("Input masses are not defined for source '$(ts.name)'!")
    end


    summaries = Dict{String, Any}()

    #  -- compute masses
    ns = MC ? n : 1             # make only one run if MC == false
    m_outs = Array{MassDict}(undef, ns)

    for i in 1:ns
        m_outs[i] = massflow(sys, M_in, MC=MC, scale_reliability=scale_reliability, rng=rng)
    end

    ## quantiles to calculate
    qq = [0.1, 0.5, 0.9]

    # --  recovery ratio
    tmp = hcat((recovery_ratio(m, M_in, sys) for m in m_outs)...)

    rr = hcat(mean(tmp, dims=2),
              std(tmp, dims=2),
              NamedArray(mapslices(x -> quantile(x, qq), tmp.array, dims=2)))
    setnames!(rr, SUBSTANCE_NAMES, 1) #
    setnames!(rr, ["mean", "sd", ["q_$i" for i in qq]...], 2)
    rr.dimnames = (:substance, :stats)

    summaries["recovery_ratio"] = rr

    # --  recovered
    tmp = hcat((recovered(m) for m in m_outs)...)

    rm = hcat(mean(tmp, dims=2),
              std(tmp, dims=2),
              NamedArray(mapslices(x-> quantile(x, qq), tmp.array, dims=2)))
    setnames!(rm, SUBSTANCE_NAMES, 1)
    setnames!(rm, ["mean", "sd", ["q_$i" for i in qq]...], 2)
    rm.dimnames = (:substance, :stats)

    summaries["recovered"] = rm


    # --  losses
    tmp = cat((lost(m) for m in m_outs)..., dims=3)

    ll = NamedArray(cat(mean(tmp.array, dims=3),
                        std(tmp.array, dims=3),
                        mapslices(x-> quantile(x, qq), tmp.array, dims=3),
                        dims=3))

    setnames!(ll, SUBSTANCE_NAMES, 1)
    setnames!(ll, ["air loss", "soil loss", "water loss"],2)
    setnames!(ll, ["mean", "sd", ["q_$i" for i in qq]...], 3)
    ll.dimnames = (:substance, :losses, :stats)

    summaries["lost"] = ll

    # -- losses per functional group
    tmp = cat((functional_group_losses(m, M_in, sys) for m in m_outs)..., dims=3)

    ll = NamedArray(cat(mean(tmp.array, dims=3),
                        std(tmp.array, dims=3),
                        mapslices(x-> quantile(x, qq), tmp.array, dims=3),
                        dims=3))

    setnames!(ll, SUBSTANCE_NAMES, 1)
    functional_groups = [:U, :S, :C, :T, :D]
    nn = vcat("entered", [["$(f)_airloss", "$(f)_soilloss", "$(f)_waterloss"] for f in functional_groups]...)
    setnames!(ll, nn, 2)
    setnames!(ll, ["mean", "sd", ["q_$i" for i in qq]...], 3)
    ll.dimnames = (:substance, :losses, :stats)

    summaries["functional_group_losses"] = ll

    # --  entered
    summaries["entered"] = entered(M_in, sys)

    # --  flows per technology
    if techflows
        techflows = Dict{Tech, NamedArray}()

        for tech in keys(m_outs[1]) # loop over all techs
            tmp = cat((m[tech] for m in m_outs)..., dims=3)
            ll = NamedArray(cat(mean(tmp.array, dims=3),
                                std(tmp.array, dims=3),
                                mapslices(x -> quantile(x, qq), tmp.array, dims=3),
                                dims=3))
            setnames!(ll, SUBSTANCE_NAMES, 1)
            setnames!(ll, collect(keys(tmp.dicts[2])), 2)
            setnames!(ll, ["mean", "sd", ["q_$i" for i in qq]...], 3)

            techflows[tech] = ll
        end
        summaries["tech_flows"] = techflows
    end

    return(summaries)
end


"""
    $TYPEDSIGNATURES

Performs Monte Carlo massflow calculations and add the summary statistics to
the system properties.

## Arguments:
- `M_in`: a dictionary containing for each source the inflows of each substance.
- `MC`: if false, the expected values of the Dirichlet distribution is used as transfer
   coefficients. Else, the transfer coefficients are sampled from a Dirichlet distribution.
## Keyword arguments
- `n`: number of Monte Carlo simulations. Ignored if `MC=false`.
- `techflows`: if true, the flows of the individual techs are summarized.
- `scale_reliability`: factor to scale the `transC_reliability` of all `Techs`.
- `rng`: optional, a random generator. This is only needed for multi-threading to obtain thread-safety.
"""
function massflow_summary!(s::System, args...; kwargs...)
    s.properties["massflow_stats"] = massflow_summary(s, args...; kwargs...)
end

"""
    $TYPEDSIGNATURES

Performs Monte Carlo massflow calculations and adds the summary statistics to
the to each system _using multi-threading_.
Make sure the that you start Julia with multiple threads!

## Arguments:
- `M_in`: a dictionary containing for each source the inflows of each substance.
- `MC`: if false, the expected values of the Dirichlet distribution is used as transfer
   coefficients. Else, the transfer coefficients are sampled from a Dirichlet distribution.
## Keyword arguments
- `n`: number of Monte Carlo simulations. Ignored if `MC=false`.
- `techflows`: if true, the flows of the individual techs are summarized.
- `scale_reliability`: factor to scale the `transC_reliability` of all `Techs`.
- `rng`: optional, a random generator. This is only needed for multi-threading to obtain thread-safety.
"""
function massflow_summary_parallel!(systems::Vector{System}, M_in::Dict;
                                    MC::Bool=true, n::Int=100, techflows::Bool=false,
                                    scale_reliability::Real=1.0)

    Threads.nthreads()==1 && @warn "Start Julia with multiple threads to benefit from parallelization!"

    # define a separate random number generator for each thread
    mt = MersenneTwister(1)
    rngs = [mt; accumulate(Future.randjump, fill(big(10)^20, Threads.nthreads()-1), init=mt)]

    p = ProgressMeter.Progress(length(systems), dt=1, desc="Compute massflows:")
    Threads.@threads for s in systems
        massflow_summary!(s, M_in, MC=MC, n=n,
                          scale_reliability=scale_reliability,
                          techflows=techflows,
                          rng=rngs[Threads.threadid()])
        ProgressMeter.next!(p)
    end

end

"""
    $TYPEDSIGNATURES

Scale all massflow summary statistics by `n_users`.
"""
function scale_massflows!(sys::System, n_users::Real)
    haskey(sys.properties, "massflow_stats") || error("`massflow_stats` are not  yet calulated! Run `massflow_summary!(system)`.")
    for v in values(sys.properties["massflow_stats"])
        v .*= n_users
    end
    sys
end

"""
    $TYPEDSIGNATURES

Scale all massflow summary statistics by `n_users` and return an independent
copy of the updated system.
"""
scale_massflows(sys::System, n_users::Real) = scale_massflows!(deepcopy(sys), n_users)
