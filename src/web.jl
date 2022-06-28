## -------------------------------------------------------
## This file contains functions that are specifically written for
## webservice. You almost certainly do not want to use them otheriwse!
## -------------------------------------------------------


## Compute the SAS based on a dict of TASs
##   `tas, tas_components = appropriateness(tech_file, case_file);`
## provides the `tas` Dict
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



"""
    $TYPEDSIGNATURES

This function is almost identical to `select_systems` except the additional `tas`
argument which is obtained by:

`tas, tas_components = appropriateness(tech_file, case_file);`


## Arguments
- `n_select::Int` Number of systems to select (if possible)
- `tas::Dict{String}{Float64}` Result from `appropriateness(tech_file, case_file)`
- `target = "sysappscore"` value used to rank systems. Can be a string
  with the name of a system property such as `"sysappscore"`,
  `"connectivity"`, or `"ntechs"`. For massflow statistics is needs to be a
`Pair` such as `("phosphor" => "recovery_ratio")`
- `maximize::Bool = true` If `true` the system with the largest `target`
values are selected. If `false` the smallest.
- `selection_type = "diverse"` Must be either `"diverse"` or
 `"ranking"`. If `"ranking"`, the systems with the largest (or
 smallest) target values are returned. If `"diverse"`, the returned
 systems have a large (or small) target value but are also as diverse as
 possible. Diversity is mainly determined by the system templates.

The following optional arguments may be used to restrict the selection further:
- `techs_include`
- `techs_exclude`
- `templates_include`
- `templates_exclude`
For the templates only the first few characters must be provided.

Note, this function may add properties to the input systems! Any of
the following properties may be added if missing:

- `template`
- `ntech`
- `connectivity`
"""
function select_systems_web(systems::Array{System}, n_select::Int,
                            tas::Dict{String}{Float64};
                            target = "sysappscore",
                            maximize::Bool = true,
                            selection_type::String = "diverse",
                            techs_include::Array{String}=["ALL"],
                            techs_exclude::Array{String}=String[],
                            templates_include::Array{String}=["ALL"],
                            templates_exclude::Array{String}=String[])

    # check if the required properties exists
    for p in ("ntechs", "connectivity", "template")
        haskey(systems[1].properties, "template") ||
            error("Systems have no property '$p'. Run $(p)!.(systems) first.")
    end

    # filter general condition
    systems = prefilter(systems,
                        techs_include,
                        techs_exclude,
                        templates_include,
                        templates_exclude)

    if length(systems) == 0
        return System[]
    end
    n_select = min(n_select, length(systems))

    # select target
    if target == "sysappscore"
        targets = [sysappscore_web(s, tas) for s in systems]
    elseif target == "connectivity"
        targets = [s.properties["connectivity"] for s in systems]
    elseif target == "ntechs"
        targets = [s.properties["ntechs"] for s in systems]
    elseif target isa Pair
        substance, stat = target
        # error checking
        (substance ∈ SUBSTANCE_NAMES || substance == "all") ||
            error("'$(substance)' is not a known substance!\n  Choose one of: $(SUBSTANCE_NAMES)")
        stats = ["recovery_ratio", "recovered", "entered", "lost"]
        stat ∈ stats||
            error("'$(stat)' is not a known massflow statistic!\n  Choose one of: $(stats)")
        haskey(systems[1].properties, "massflow_stats") || error("You must first run `massflow_summary!` or `massflow_summary_parallel!`.")

        # get values

        if stat == "entered"
            if substance == "all"
                targets = [sum(s.properties["massflow_stats"][stat][:, "entered"]) for s in systems]
            else
                targets = [s.properties["massflow_stats"][stat][substance, "entered"] for s in systems]
            end
        elseif stat == "lost"
            if substance == "all"
                targets = [sum(s.properties["massflow_stats"][stat][:, :, "mean"]) for s in systems]
            else
                targets = [sum(s.properties["massflow_stats"][stat][substance, :, "mean"]) for s in systems]
            end
        else
            if substance == "all"
                targets = [sum(s.properties["massflow_stats"][stat][:, "mean"]) for s in systems]
            else
                targets = [s.properties["massflow_stats"][stat][substance, "mean"] for s in systems]
            end
        end
    else
        error("target '$(target)' unknown!")
    end

    # flip sign to minimize
    if !maximize
        targets *= -1
    end

    # choose the type of selection
    if selection_type == "diverse"
        return select_diverse(systems, n_select, targets)
    elseif selection_type == "ranking"
        return select_ranking(systems, n_select, targets)
    else
        error("'selection_type' must be either \"diverse\" or \"ranking\"!")
    end
end


# -----------
# Massflow scaling

function _scale_web!(d::Dict, n_users)
    for (k,v) in d
        if v isa Dict
            _scale_web!(v, n_users)
        else
            d[k] = v * n_users
        end
    end
end

# -----------
# JSON export with `tas` and `n_users` argument

function SystemJSON(sys::System, tas::Dict{String}{Float64}, n_users::Real=1)
    n_users >= 0 || error("`A negative number of user is not allowed!`.")

    s = SystemJSON(sys)
    # update SAS field
    s.properties["sysappscore"] = Santiago.sysappscore_web(sys, tas)
    # update massflows
    _scale_web!(s.properties["massflow_stats"], n_users)

    return s
end


JSON3.write(sys::System, tas::Dict{String}{Float64}, n_users::Real=1) = JSON3.write(SystemJSON(sys, tas, n_users))
JSON3.write(io::IO, sys::T, tas::Dict{String}{Float64}, n_users::Real=1; kw...) where T <: System = JSON3.write(io, SystemJSON(sys, tas, n_users); kw...)

JSON3.write(sys::Array{System}, tas::Dict{String}{Float64}, n_users::Real=1) = JSON3.write([SystemJSON(s, tas, n_users) for s in sys])
JSON3.write(io::IO, sys::Array{T}, tas::Dict{String}{Float64}, n_users::Real=1; kw...) where T <: System = JSON3.write(io, [SystemJSON(s, tas, n_users) for s in sys]; kw...)


# -----------
# keep '_trans' in tech names
"""
    $TYPEDSIGNATURES

List all technologies that are used by the systems of each templates.
However, this version distinguishes between 'tech' and 'tech_trans'!
"""
function techs_per_template_web(systems::Array{System})
    haskey(systems[1].properties, "template") ||
        error("No templates assigned! Run `template!` first.")
    d = Dict{String, Set{String}}()
    for s in systems
        templ = s.properties["template"]
        for tech in s.techs
            techname = replace(tech.name, r"(_[0-9]+)?" => "")
            if haskey(d, templ)
                push!(d[templ], techname)
            else
                d[templ] = Set([techname])
            end
        end
    end
    d
end
