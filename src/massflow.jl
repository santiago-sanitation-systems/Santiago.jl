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

issource(t::Tech) = length(t.inputs) == 0
issink(t::Tech) = length(t.outputs) == 0


"""
Compute massflows of a system. Optionally with Monte Carlo (MC) simulation.

Arguments:
- if `MC` is false, the transfer coefficients are the expected values of the Dirichlet distribution
- if `MC` is true, the transfer coefficients are sampled form Dirichlet distribution
- `scale_reliability` a factor to scale the `transC_reliability` of all Techs.
"""
function massflow(sys::System, M_in::Dict; MC::Bool=false, scale_reliability::Real=1.0)::MassDict

    M_out = Dict{Tech, NamedArray{Float64}}()
    transC_MC = Dict{Tech, NamedArray{Float64,2}}()

    for t in sys.techs
        # M_out[t] = zeros(t.transC)
        M_out[t] = 0.0*t.transC
        if MC
            transC_MC[t] = sample_transC(t.transC, t.transC_reliability * scale_reliability)
        else
            transC_MC[t] = t.transC
        end
    end


    # iterate over all sources
    for t in filter(issource, sys.techs)
        M_new = M_in[t] .* transC_MC[t]
        M_out[t] = M_new
        propagate_M!(t, M_new[:,1:end-3], M_out, transC_MC, sys)
    end

    return M_out

end


function propagate_M!(t::Tech, M_new::NamedArray{Float64}, M_out::MassDict,
                      transC_MC::Dict{Tech, NamedArray{Float64,2}}, sys::System)

    for (i,p) in enumerate(t.outputs)

        # identify the connected Tech
        next_t = collect(filter(c -> c[1] == p && c[2] == t, sys.connections))[1][3]
        M_new2 = M_new[:,i] .* transC_MC[next_t] # the new mass

        M_out[next_t][:,:] += M_new2 # store additional mass
        # do not propagate losses
        propagate_M!(next_t, M_new2[:,1:end-3], M_out, transC_MC, sys)
    end
end


# Sample a random transition matrix. Each row is Dirichlet distributed
function sample_transC(transC::AbstractArray, transC_reliability::AbstractArray)
    # m = zeros(transC)
    m = 0.0*transC
    for i in 1:NSUBSTANCE
        i_zero = transC[i,:] .<= 0.0
        alpha = transC[i,.!i_zero]*transC_reliability[i]
        m[i,.!i_zero] = rand( Dirichlet(alpha.array),1 )
    end
    m
end



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

    summaries = Dict{String, NamedArray{Float64}}()

    #  -- compute masses
    ns = MC ? n : 1             # make only one run if MC == false
    m_outs = [massflow(sys, M_in, MC=MC, scale_reliability=scale_reliability) for i in 1:ns]

    ## quantiles to calculate
    qq = [0.2, 0.5, 0.8]

    # --  recovery ratio
    tmp = hcat((recovery_ratio(m, M_in, sys) for m in m_outs)...)
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
    summaries["entered"] = entered(M_in, sys)

    return(summaries)
end
