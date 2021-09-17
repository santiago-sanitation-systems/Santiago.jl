## -------------------------------------------------------
## This file contains functions that are specifically written for
## webservice. You almost certainly do not want to use them otheriwse!
## -------------------------------------------------------


## Compute the SAS based on a dict of TASs
## `tas, tas_components = appropriateness(tech_file, case_file);`
### provides the `tas` Dict
function sysappscore_web(s::System, tas::Dict{String}{Float64}; α = 0.5)::Float64

    appscores = Float64[]
    for t in s.techs
        push!(appscores, tas[Santiago.simplifytechname(t.name)])
    end

    # return -1 for negative TAS
    any(appscores .< 0) && return -1.0

    n = length(appscores)
    logsum = sum(Base.log.(appscores))
    score = exp( logsum/(α*(n-1.0) + 1.0) )
    return score
end
