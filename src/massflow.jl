# -----------
# massflow

using Distributions
using NamedArrays

export massflow
export lost
export recovered
export entered
export recovery_ratio
export massflow_summary


const MassDict = Dict{Tech, <:NamedArray{Float64}}

issource{T <: AbstractTech}(t::T) = length(t.inputs) == 0
issink{T <: AbstractTech}(t::T) = length(t.outputs) == 0


"""
Compute massflows of a system. Optionally with Monte Carlo (MC) simulation.

Arguments:
- if `MC` is false, the transfer coefficients are the expected values of the Dirichlet distribution
- if `MC` is true, the transfer coefficients are sampled form Dirichlet distribution
- `scale_reliability` a factor to scale the `transC_reliability` of all Techs.
"""
function massflow(sys::System, M_in::Dict{Tech, Array{Float64, 1}};
                  MC::Bool=false, scale_reliability::Real=1.0)

    M_out = Dict{Tech, NamedArray{Float64}}()

    for sub in SUBSTANCE_NAMES

        # derive (random) adjacent matrix
        Pmean, rel_vect = get_adj_mat(sys, substance)

        if MC
            P = sample_P(Pmean, rel_vect)
        else
            P = Pmean
        end

        # calulate flows
        calc_massflows(P, inputs)

    end

    return M_out

end


function get_adj_mat(sys::System, substance::String)

    # -- get all Techs and all connections
    allTechs = filter(t -> typeof(t) == Tech, sys.techs)
    allConn = filter(c -> !any(contains.([c[2].name, c[3].name], "::")), sys.connections)
    allConn_TechCombs = filter(c -> any(contains.([c[2].name, c[3].name], "::")), sys.connections)

    for t in filter(t -> typeof(t) == TechCombined, sys.techs)
                union!(allTechs, t.internal_techs)
                union!(allConn, t.internal_connections)
    end
    allTechs = collect(allTechs)
    allConn = collect(allConn)

    # add connection from or to TechComb
    for c in allConn_TechCombs
        prod, from_tech, to_tech = c
        if contains(from_tech.name, "::")

            int_con_prod = collect(filter(c -> c[1] == prod, from_tech.internal_connections))
            ffilter = function (t::AbstractTech)
                prod in t.outputs &&
                    !any(getindex.(int_con_prod, 2) == t)
            end

            from_tech = collect(filter(ffilter, from_tech.internal_techs))[1]
        end
        if contains(to_tech.name, "::")

            int_con_prod = collect(filter(c -> c[1] == prod, to_tech.internal_connections))
            ffilter = function (t::AbstractTech)
                prod in t.inputs &&
                    !any(getindex.(int_con_prod, 3) == t)
            end

            to_tech = collect(filter(ffilter, to_tech.internal_techs))[1]
        end

        push!(allConn, (prod, from_tech, to_tech))
    end


    # -- build matrix
    technames = getfield.(allTechs, :name)
    lossnames = vcat([["$(n)_airloss", "$(n)_soilloss", "$(n)_waterloss"] for n in technames]...)
    sinkrecoverd = ["$(s.name)_recovered" for s in allTechs if issink(s)]
    Pnames = vcat(technames, lossnames, sinkrecoverd)
    P = NamedArray(zeros(length(Pnames), length(Pnames)), (Pnames, Pnames), ("from", "to"))

    # fill in transfer coefficients
    for c in allConn
        prod, from_tech, to_tech = c
        P[from_tech.name, to_tech.name] += from_tech.transC[substance][prod]
    end

    # add all losses
    for t in allTechs
        P[t.name, t.name * "_airloss"] = t.transC[substance][Product("airloss")]
        P[t.name, t.name * "_soilloss"] = t.transC[substance][Product("soilloss")]
        P[t.name, t.name * "_waterloss"] = t.transC[substance][Product("waterloss")]
    end

    # add 'recovered' for sinks
    for t in filter(issink, allTechs)
        P[t.name, t.name * "_recovered"] = t.transC[substance][Product("recovered")]
    end

    # compile transC_reliability vector
    rel_vect = NamedArray(zeros(length(Pnames)), (Pnames, ))
    for t in allTechs
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



# -----------
# summary functions

function lost(M_out::MassDict)
    sum(m[:,(end-2):end] for (t,m) in M_out)
end


function recovered(M_out::MassDict)
    sum(m[:,1:end-3] for (t,m) in M_out if issink(t))
end


function entered(M_in::Dict, sys::System)
    NamedArray(sum(m for (t,m) in M_in if t in sys.techs), (SUBSTANCE_NAMES,))
end


function recovery_ratio(M_out::MassDict, M_in::Dict, sys::System)
    mass_in = entered(M_in, sys)
    f = recovered(M_out) ./ mass_in
    f[mass_in .== 0.0] = 1.0  # define: 0/0 := 1.0
    setnames!(f, "ratio", 2, 1)
    return(f)
end


"""
Calculate summary statistics of a Monte Carlo massflow results
"""

function massflow_summary(sys::System, M_in::Dict; MC::Bool=true, n::Int=100,
                          scale_reliability::Real=1.0)


    # -- convert M_in
    M_in2 = Dict{Tech, Array{Float64,1}}()

    sources = [t for t in sys.techs if issource(t)]
    for ts in sources
        haskey(M_in, ts.name) || error("Input masses are not defined for source '$(ts.name)'!")
        m_in = M_in[ts.name]
        size(m_in) == (4,) || error("Input masses defined for source '$(ts.name)' have dimensions $(size(M_in[ts.name])) instead of (4,)!")

        M_in2[ts] = m_in
    end


    summaries = Dict{String, NamedArray{Float64}}()

    #  -- compute masses
    ns = MC ? n : 1             # make only one run if MC == false
    m_outs = [massflow(sys, M_in2, MC=MC, scale_reliability=scale_reliability) for i in 1:ns]

    ## quantiles to calculate
    qq = [0.2, 0.5, 0.8]

    # --  recovery ratio
    tmp = hcat((recovery_ratio(m, M_in2, sys) for m in m_outs)...)
    rr = hcat(mean(tmp, 2),
              std(tmp, 2),
              NamedArray(mapslices(x -> quantile(x, qq), tmp.array, 2)))
    setnames!(rr, SUBSTANCE_NAMES, 1) #
    setnames!(rr, ["mean", "sd", ["q_$i" for i in qq]...], 2)

    summaries["recovery_ratio"] = rr

    # --  recovered
    tmp = hcat((recovered(m) for m in m_outs)...)

    rm = hcat(mean(tmp, 2),
              std(tmp, 2),
              NamedArray(mapslices(x-> quantile(x, qq), tmp.array, 2)))
    setnames!(rm, SUBSTANCE_NAMES, 1)
    setnames!(rm, ["mean", "sd", ["q_$i" for i in qq]...], 2)

    summaries["recovered"] = rm


    # --  losses
    tmp = cat(3, (lost(m) for m in m_outs)...)

    ll = NamedArray(cat(3,
                        mean(tmp.array, 3),
                        std(tmp.array, 3),
                        mapslices(x-> quantile(x, qq), tmp.array, 3)))

    setnames!(ll, SUBSTANCE_NAMES, 1)
    setnames!(ll, ["air loss", "soil loss", "other loss"],2)
    setnames!(ll, ["mean", "sd", ["q_$i" for i in qq]...], 3)

    summaries["lost"] = ll


    # --  entered
    summaries["entered"] = entered(M_in2, sys)

    return(summaries)
end
