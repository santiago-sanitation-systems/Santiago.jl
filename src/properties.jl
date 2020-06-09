# -----------
# functios to asses and select systems

export sysappscore


""" Compute the SAS of a system."""
function sysappscore(s::System; alpha::Float64 = 0.5)

    appscores = Float64[]
    for component in s.techs
        append!(appscores, component.appscore)
    end

    n = length(appscores)
    logsum = sum(Base.log.(appscores))
    score = exp( logsum/(alpha*(n-1.0) + 1.0) )
    return score
end
