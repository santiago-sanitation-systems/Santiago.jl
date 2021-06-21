using JSON3
using QuadGK

include("performanceFunctions.jl")

export appropriateness, update_appropriateness!


# geometric mean (if length==0, returns 1)
function geomean(a)
    n = length(a)
    if n==0
        return 1.0
    else
        s = 0.0
        for ai in a
            @inbounds s += log(ai)
        end
        return exp(s / n)
    end
end

# integrate between continous distributions
function integrate(d1::T1, t1, d2::T2, t2) where T1 <: Continous where T2 <: Continous
    f(x) = d1(x, t1)*d2(x, t2)
    lw, up = t1 isa Pdf ? (minimum(d1), maximum(d1)) : (minimum(d2), maximum(d2))
    # integrate
    score, _ = quadgk(f, lw, up, rtol=1e-6, atol=1e-6)
    score
end

# summation for categorical variables
function integrate(d1::T1, t1, d2::T2, t2) where T1 <: Discrete where T2 <: Discrete
    all(keys(d1.d) .== keys(d2.d)) || error("Categories do not match:\n $(keys(d1.d))\n $(keys(d2.d))")

    score = 0.0
    for k in keys(d1.d)
        score += d1(k, t1) * d2(k, t2)
    end
    score
end


function get_distribution(attribute)
    p = attribute[:parameters]
    p = Dict((Symbol(k), v) for (k,v) in p) # convert keys to Symbols
    tt =     attribute[:type] |> lowercase |> uppercasefirst |> Symbol
    ff = attribute[:function] |> lowercase |> uppercasefirst |> Symbol
    if ff == :Categorical
        if tt == :Pdf
            sum(abs, values(p)) ≈ 1.0 || error("Probabilities must sum to 1, not $(sum(abs, values(p)))!\n Attribute: '$attribute'")
        elseif tt == :Performance
            e = extrema(values(p))
            (0 <= e[1] <= e[2] <= 1) || error("Performance must be ∈ [0,1], not $(e)!\n Attribute: '$attribute'")
        end
        d = getfield(Santiago, ff)(p)
    else
        d = getfield(Santiago, ff)(; p...)
    end
    t = getfield(Santiago, tt)()
    d, t
end



function techscore(techattributes, caseattributes)
    attr = intersect(keys(techattributes), keys(caseattributes))
    d = Dict{Symbol, AbstractFloat}()
    for a in attr
        @debug "  $a"
        d1, t1 = get_distribution(techattributes[a])
        d2, t2 = get_distribution(caseattributes[a])

        (((t1 isa Pdf) & (t2 isa Performance)) | ((t1 isa Performance) & (t2 isa Pdf))) ||
            error("Attribute '$a': Only a 'Pdf'/'Pmf' and a 'Performance' function can be combined! ")
        d[a] = integrate(d1, t1, d2, t2)
    end
    d
end



function appropriateness(techs::JSON3.Array, case::JSON3.Object)
    @info "Case: '$(case.name)'"

    TAS = Dict()
    for t in techs
        @debug "Calculate TAS for $(t.name):"
        TAS[t.name] = techscore(t.attributes, case.attributes)
    end
    Dict(k => geomean(values(v)) for (k,v) in TAS), TAS
end

"""
# Calculate the technology appropriateness score (TAS) for each technology

```
appropriateness(technology_file::AbstractString, case_file::AbstractString)
```

## Parameters
- `technology_file`: name of a json file with technologie definitions
- `case_file`: name of a json file with case definition

## Values
Two dictionaries. The first one return the TAS for each technology,
the second one contains the scores separately for each attribute.
"""
function appropriateness(technology_file::AbstractString, case_file::AbstractString)

    techs = open(technology_file,"r") do f
        JSON3.read(f)
    end

    case = open(case_file,"r") do f
        JSON3.read(f)
    end

    appropriateness(techs, case)
end


# ---------------------------------
# update exiting techs with new TAS

function update_appropriateness!(techs::Array{<:AbstractTech}, tas::Dict{String, Float64})
    for t in techs
        nn = simplifytechname(t.name)
        nn ∈ keys(tas) ? t.appscore[1] = tas[nn] : error("Appropriateness for '$(nn)' not defined!")
    end
end
