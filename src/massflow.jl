# -----------
# massflow

export massflow
export lost
export recovered
export entered
export recovery_ratio


const MassDict = Dict{Tech, <:Array{Float64}}

issource(t::Tech) = length(t.inputs) == 0
issink(t::Tech) = length(t.outputs) == 0


function massflow(sys::System, M_in::MassDict)::MassDict

    M_out = Dict{Tech, Array{Float64}}()
    # init Dict with zeros
    for t in sys.techs
        if issink(t)
            M_out[t] = zeros(NSUBSTANCE, 4)
        else
            M_out[t] = zeros(NSUBSTANCE, length(t.outputs) + 3)
        end
    end

    # iterate over all sources
    for t in filter(issource, sys.techs)
        M_new = M_in[t] .* t.transC
        M_out[t] = M_new
        propagate_M!(t, M_new[:,1:end-3], M_out, sys)
    end

    return M_out

end


function propagate_M!(t::Tech, M_new::Array{Float64}, M_out::MassDict, sys::System)

    for (i,p) in enumerate(t.outputs)

        # identify the connected Tech
        next_t = collect(filter(c -> c[1] == p && c[2] == t, sys.connections))[1][3]
        M_new2 = M_new[:,i] .* next_t.transC # the new mass

        M_out[next_t][:,:] += M_new2 # store additional mass
        # do not propagate losses
        propagate_M!(next_t, M_new2[:,1:end-3], M_out, sys)
    end
end


# summary functions

function lost(M_out::MassDict)
    sum(m[:,(end-2):end] for (t,m) in M_out)
end

function recovered(M_out::MassDict)
    sum(m[:,1:end-3] for (t,m) in M_out if issink(t))
end

function entered(M_in::MassDict, sys::System)
    sum(m for (t,m) in M_in if t in sys.techs)
end

function recovery_ratio(M_out::MassDict, M_in::MassDict, sys::System)
    mass_in = entered(M_in, sys)
    f = recovered(M_out) ./ mass_in
    f[mass_in .== 0.0] = 1.0  # define: 0/0 := 1.0
    return(f)
end
