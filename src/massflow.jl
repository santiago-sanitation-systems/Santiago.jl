# -----------
# massflow

using LinearAlgebra
using Distributions
using NamedArrays

export massflow
export lost
export recovered
export entered
export recovery_ratio
export massflow_summary
export issource
export issink

const MassDict = Dict{Tech, NamedArray{Float64}}

issource(t::T) where T <: AbstractTech = length(t.inputs) == 0
issink(t::T) where T <: AbstractTech = length(t.outputs) == 0


"""
Compute massflows of a system. Optionally with Monte Carlo (MC) simulation.

Arguments:
- if `MC` is false, the transfer coefficients are the expected values of the Dirichlet distribution
- if `MC` is true, the transfer coefficients are sampled form Dirichlet distribution
- `scale_reliability` a factor to scale the `transC_reliability` of all Techs.
"""
function massflow(sys::System, M_in::Dict{String, Dict{String, T}};
                  MC::Bool=false, scale_reliability::Real=1.0) where T <: Real

    # --- calculate flows
    flow_mats = Dict{String, AbstractArray}()
    M_out = MassDict()
    Ps = Dict{String, AbstractArray}()

    for substance in SUBSTANCE_NAMES

        # -- derive (random) adjacent matrix
        Pmean, rel_vect = get_adj_mat(sys, substance)

        if MC
            P = sample_P(Pmean, rel_vect)
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
function sample_P(P::AbstractArray, transC_reliability::AbstractArray)
    # m = zeros(P)
    P2 = 0.0*P
    for i in 1:size(P,1)
        i_zero = P[i,:] .<= 0.0
        alpha = P[i,.!i_zero] * transC_reliability[i]
        P2[i,.!i_zero] = rand( Dirichlet(alpha.array), 1 )
    end
    P2
end



function calc_massflows(P::AbstractArray, inp::AbstractVector)

    size(P,1) == size(P,2) || error("'P' must be a square matrix!")
    size(P,1) == length(inp) || error("'inp' must have $size(P,1) elements")

    names = P.dicts[1]
    P = P.array
    inp = inp.array

    inp = inp'
    m = inp*P * inv(I - P) # not an optimal implementation from a numerical point of view...

    flows = [(m+inp)[i]*P[i,j] for i=1:size(P,1), j=1:size(P,1)]

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
    f[mass_in .== 0.0] = 1.0  # define: 0/0 := 1.0
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
Calculate summary statistics of a Monte Carlo massflow results
"""
function massflow_summary(sys::System, M_in::Dict; MC::Bool=true, n::Int=100,
                          scale_reliability::Real=1.0)


    # -- convert M_in

    sources = [t for t in sys.techs if issource(t)]
    for ts in sources
        haskey(M_in, ts.name) || error("Input masses are not defined for source '$(ts.name)'!")
    end


    summaries = Dict{String, NamedArray{Float64}}()

    #  -- compute masses
    ns = MC ? n : 1             # make only one run if MC == false
    m_outs = [massflow(sys, M_in, MC=MC, scale_reliability=scale_reliability) for i in 1:ns]

    ## quantiles to calculate
    qq = [0.1, 0.5, 0.9]

    # --  recovery ratio
    tmp = hcat((recovery_ratio(m, M_in, sys) for m in m_outs)...)
    rr = hcat(mean(tmp, 2),
              std(tmp, 2),
              NamedArray(mapslices(x -> quantile(x, qq), tmp.array, 2)))
    setnames!(rr, SUBSTANCE_NAMES, 1) #
    setnames!(rr, ["mean", "sd", ["q_$i" for i in qq]...], 2)
    rr.dimnames = (:substance, :stats)

    summaries["recovery_ratio"] = rr

    # --  recovered
    tmp = hcat((recovered(m) for m in m_outs)...)

    rm = hcat(mean(tmp, 2),
              std(tmp, 2),
              NamedArray(mapslices(x-> quantile(x, qq), tmp.array, 2)))
    setnames!(rm, SUBSTANCE_NAMES, 1)
    setnames!(rm, ["mean", "sd", ["q_$i" for i in qq]...], 2)
    rm.dimnames = (:substance, :stats)

    summaries["recovered"] = rm


    # --  losses
    tmp = cat(3, (lost(m) for m in m_outs)...)

    ll = NamedArray(cat(3,
                        mean(tmp.array, 3),
                        std(tmp.array, 3),
                        mapslices(x-> quantile(x, qq), tmp.array, 3)))

    setnames!(ll, SUBSTANCE_NAMES, 1)
    setnames!(ll, ["air loss", "soil loss", "water loss"],2)
    setnames!(ll, ["mean", "sd", ["q_$i" for i in qq]...], 3)
    ll.dimnames = (:substance, :losses, :stats)

    summaries["lost"] = ll

    # -- losses per functional group
    tmp = cat(3, (functional_group_losses(m, M_in, sys) for m in m_outs)...)

    ll = NamedArray(cat(3,
                        mean(tmp.array, 3),
                        std(tmp.array, 3),
                        mapslices(x-> quantile(x, qq), tmp.array, 3)))

    setnames!(ll, SUBSTANCE_NAMES, 1)
    functional_groups = [:U, :S, :C, :T, :D]
    nn = vcat("entered", [["$(f)_airloss", "$(f)_soilloss", "$(f)_waterloss"] for f in functional_groups]...)
    setnames!(ll, nn, 2)
    setnames!(ll, ["mean", "sd", ["q_$i" for i in qq]...], 3)
    ll.dimnames = (:substance, :losses, :stats)

    summaries["functional_group_losses"] = ll

    # --  entered
    summaries["entered"] = entered(M_in, sys)

    return(summaries)
end
