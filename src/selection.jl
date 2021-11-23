# -----------
# functions for system selection


using Clustering: kmeans, assignments
using Statistics: quantile

export select_systems, pick_systems


# assign N values to categories relative to the weights 'w' with at least one value per in each category
function assign_categories(N::Int, w::AbstractArray)
    ncat = length(w)

    w = sum(w) > 0 ? w ./ sum(w) : fill(1/ncat, ncat) # catch corner case of all zeros
    if  N >= ncat
        nn = floor.(Int, w*(N-ncat)) #nn is the vector of number of selected items per cat
        r = N-ncat - sum(nn) # remaining selections to distribute within cats
        nn[partialsortperm(w*(N-ncat) .- nn, 1:r, rev=true)] .+= 1 # rank the categories according to the rest that was floored before and distribute r
        nn .+= 1 # at leat one item is selected from each catetgory
    else
        nn = zeros(Int, length(w))
        nn[partialsortperm(w, 1:N, rev=true)] .+= 1
    end
    return nn
end




# Compute Kmeans clusters (Euclidian distance is used)
function getClusters(sysProperties::AbstractArray,  ncluster::Int)
    for i in 1:size(sysProperties,2)
        sysProperties[:,i] = (sysProperties[:,i] .- mean(sysProperties[:,i])) ./ std(Float64.(sysProperties[:,i]))
    end
    km = kmeans(Float64.(sysProperties)', ncluster)
    return km
end



# function to filter techs
has_techs(techs_include, sys) = techs_include == ["ALL"] ?
    true :
    all(in.(techs_include, Ref(simplifytechname.(t.name for t in sys.techs))))

has_not_techs(techs_exclude, sys) = length(techs_exclude)==0 ?
    true :
    ! any(in.(techs_exclude, Ref(simplifytechname.(t.name for t in sys.techs))))


# function to templates
function is_template(templates_include, sys)
    if templates_include == ["ALL"]
        return true
    else
        # regex to look for a string th the same beginning
        pattern = (Regex("^$(p)") for p in templates_include)
        return any(occursin.(pattern, sys.properties["template"]))
    end
end

function is_not_template(templates_exclude, sys)
    if length(templates_exclude) == 0
        return true
    else
        # regex to look for a string th the same beginning
        pattern = (Regex("^$(p)") for p in templates_exclude)
        return ! any(occursin.(pattern, sys.properties["template"]))
    end
end


function prefilter(systems::Array{System},
                   techs_include::Array{String}=["ALL"],
                   techs_exclude::Array{String}=String[],
                   templates_include::Array{String}=["ALL"],
                   templates_exclude::Array{String}=String[])

    filter(sys -> has_techs(techs_include, sys) &&
           has_not_techs(techs_exclude, sys) &&
           is_template(templates_include, sys) &&
           is_not_template(templates_exclude, sys),
           systems)
end



"""
    $TYPEDSIGNATURES

Select a subset of maximal `n_select` systems. The function aims to
 identify systems that have a good target value.

Most system properties can serve as target. The most commonly used one is the `sysappscore`.

## Arguments
- `n_select::Int` Number of systems to select (if possible)
- `target = "sysappscore"` value used to rank systems. Can be a string
  with the name of a system property such as `"sysappscore"`,
  `"connectivity"`, or `"ntechs"`. For massflow statistics is needs to be a `Pair` of
   a product and a massflow statistic such as `("phosphor" => "recovery_ratio")`.
- `maximize::Bool = true` If `true` the system with the largest `target` values
   are selected. If `false` the smallest.
- `selection_type = "diverse"` Must be either `"diverse"` or  `"ranking"`.
  If `"ranking"`, the systems with the largest (or smallest) target values are returned. If `"diverse"`, the returned systems have a large (or small) target value but are also as diverse as possible. Diversity is mainly determined by the system templates.

The following optional arguments may be used to restrict the selection further:
- `techs_include`
- `techs_exclude`
- `templates_include`
- `templates_exclude`
For the templates only the first few characters must be provided.

## Details

As a special functionality, the argument `target` also accepts a
`Pair` of `"all"` and a massflow statistic, for example `("all" => "recovery_ratio")`.
In this case the _average_ of the massflow
statistics across all four products is used as target. Note, however,
that makes no sense for most massflow statistics!

Note, this function may add properties to the input systems! Any of
the following properties may be added if missing:

- `template`
- `sysappscore`
- `ntech`
- `connectivity`
"""
function select_systems(systems::Array{System}, n_select::Int;
                        target = "sysappscore",
                        maximize::Bool = true,
                        selection_type::String = "diverse",
                        techs_include::Array{String}=["ALL"],
                        techs_exclude::Array{String}=String[],
                        templates_include::Array{String}=["ALL"],
                        templates_exclude::Array{String}=String[])

    # compute properties if they do not exists
    haskey(systems[1].properties, "template") || template!.(systems)
    haskey(systems[1].properties, "sysappscore") || sysappscore!.(systems)
    haskey(systems[1].properties, "ntechs") || ntechs!.(systems)
    haskey(systems[1].properties, "connectivity") || connectivity!.(systems)

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
        targets = [s.properties["sysappscore"] for s in systems]
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
        targets .*= -1
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


"""
    $TYPEDSIGNATURES

Select a subset of maximal `n_select` systems. The function aims to identify
 systems that are divers while having a large target
 value. Diversity is mainly determined by the system templates.
"""
function select_diverse(systems::Array{System}, n_select::Int, targets::Array)

    # extract system properties
    IDs = [s.properties["ID"] for s in systems]
    templates = [s.properties["template"] for s in systems]
    properties = [s.properties[k] for s in systems, k in ["ntechs", "connectivity"]]

    # identify all templates used
    templates_used = unique(templates)

    ## Calculate how many systems to select per template
    ## based on the 90% quantiles of sysappscore per template
    q_scores = [quantile(abs.(targets[templates .== t]), 0.9)
                for t in templates_used]

    n_template = assign_categories(n_select, q_scores) # assign number of system per template

    selected = fill(false, length(systems))

    for (i, template) in enumerate(templates_used)
        properties_template = @view properties[templates .== template, :]
        targets_template = @view targets[templates .== template]
        selected_template = @view selected[templates .== template]

        n_sys_t = length(targets_template)
        if n_sys_t < n_template[i]
            @debug "Maximal $(n_sys_t) (not $(n_template[i])) systems can be selected for template \"$(templates_used[i])\"!"
            n_template[i] = n_sys_t
        end
        ## find out how many unique property combination exist
        nunique = length(unique(properties_template[j,:] for j in 1:size(properties_template,1)))
        ncluster = min(nunique, n_template[i]) # ncluster cannot be bigger than number of unique data points
        if ncluster > 1

            km = getClusters(properties_template, ncluster)
            assig = assignments(km)

            ## find system with highest score per cluster
            for k in 1:length(km.counts)
                if km.counts[k] > 0
                    properties_template_clust = @view properties_template[assig .== k,:]
                    targets_template_clust = @view targets_template[assig .== k]
                    selected_template_clust = @view selected_template[assig .== k]
                    maxindex = findmax(targets_template_clust)[2] # system with the highest appscore
                    selected_template_clust[maxindex] = true # select system
                end
            end
        else
            ncluster = 0  # no cluster was made, because n_selectedsystems <= n_templates
        end
        ## Add additional systems if 'nunique' was too small
        ## (use systems with the highest score)
        if n_template[i] > ncluster
            targets_template_ns = @view targets_template[.!selected_template]
            selected_template_ns = @view selected_template[.!selected_template]
            selectidx = partialsortperm(targets_template_ns, 1:(n_template[i] - ncluster), rev=true)
            selected_template_ns[selectidx] .= true
        end

    end

    ## Add additional systems some templates had not enough systems
    ## (use systems with the highest score)
    if sum(selected) < n_select
        targets_ns = @view targets[.!selected]
        selected_ns = @view selected[.!selected]
        selectidx = partialsortperm(targets_ns, 1:(n_select - sum(selected)), rev=true)
        selected_ns[selectidx] .= true
    end

    systems[selected]
end


"""
    $TYPEDSIGNATURES

Select a subset of maximal `n_select` systems. The function selects the
 systems with the largest target values.
"""
function select_ranking(systems::Array{System}, n_select::Int, targets::Array)

    IDs = [s.properties["ID"] for s in systems]

    selected = fill(false, length(systems))
    selected[partialsortperm(targets, 1:n_select, rev=true)] .= true

    systems[selected]
end


"""
    $TYPEDSIGNATURES

Return systems with matching `ID`. May return an empty array.
"""
function pick_systems(systems::Array{System}, IDs::Array{T} where T <: AbstractString)
    filter(s -> s.properties["ID"] ∈ IDs, systems)
end
