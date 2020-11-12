# -----------
# functions for system selection


using Clustering: kmeans, assignments
using Statistics: quantile

export select_systems


# assign N values to categories relative to the weights 'w' with at least one value per in each category
function assign_categories(N::Int, w::AbstractArray)
    ncat = length(w)
    w = w ./ sum(w)
    if  N >= ncat
        nn = floor.(Int, w*(N-ncat)) #nn is the vector of number of selected items per cat
        r = N-ncat - sum(nn) # remaining selections to distribute within cats
        nn[sortperm(w*(N-ncat) .- nn, rev=true)[1:r]] .+= 1 # rank the categories according to the rest that was floored before and distribute r
        nn .+= 1 # at leat one item is selected from each catetgory
    else
        nn = zeros(Int, length(w))
        nn[sortperm(w, rev=true)[1:N]] .+= 1
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


"""
    $TYPEDSIGNATURES

Select a subset of `n_select` systems. The function aims to identify systems
 that are divers and have a good SAS.

Note, this function may modify the properties of the input systems! Any of
the following properties will be added if missing:

- `template`
- `sysappscore`
- `ntech`
- `connectivity`
"""
function select_systems(systems::Array{System}, n_select::Int;
                        techs_include::Array{String}=["ALL"],
                        techs_exclude::Array{String}=String[])

    # filter techs
    systems = filter(sys -> has_techs(techs_include, sys) && has_not_techs(techs_exclude,
                                                                           sys), systems)

    if length(systems) < n_select
        error("Cannot select $(n_select) systems. Only $(length(systems)) systems fullfill all conditions!")
    end

    # compute properties if they do not exists
    haskey(systems[1].properties, "template") || template!.(systems)
    haskey(systems[1].properties, "sysappscore") || sysappscore!.(systems)
    haskey(systems[1].properties, "ntechs") || ntechs!.(systems)
    haskey(systems[1].properties, "connectivity") || connectivity!.(systems)


    # extract system properties
    IDs = [s.properties["ID"] for s in systems]
    templates = [s.properties["template"] for s in systems]
    sas = [s.properties["sysappscore"] for s in systems]
    properties = [s.properties[k] for s in systems, k in ["ntechs", "connectivity"]]

    # identify all templates used
    templates_used = unique(templates)

    ## Calculate how many systems to select per template
    ## based on the 90% quantiles of sysappscore per template
    q_scores = [quantile(sas[templates .== t], 0.9)
                for t in templates_used]

    n_template = assign_categories(n_select, q_scores) # assign number of system per template

    selected = fill(false, length(systems))

    for (i, template) in enumerate(templates_used)
        properties_template = @view properties[templates .== template, :]
        sas_template = @view sas[templates .== template]
        selected_template = @view selected[templates .== template]

        n_sys_t = length(sas_template)
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
                properties_template_clust = @view properties_template[assig .== k,:]
                sas_template_clust = @view sas_template[assig .== k]
                selected_template_clust = @view selected_template[assig .== k]
                maxindex = findmax(sas_template_clust)[2] # system with the highest appscore
                selected_template_clust[maxindex] = true # select system
            end
        else
            ncluster = 0  # no cluster was made, because n_selectedsystems <= n_templates
        end
        ## Add additional systems if 'nunique' was too small
        ## (use systems with the highest score)
        if n_template[i] > ncluster
            sas_template_ns = @view sas_template[.!selected_template]
            selected_template_ns = @view selected_template[.!selected_template]
            selectidx = sortperm(sas_template_ns, rev=true)[1:(n_template[i] - ncluster)]
            selected_template_ns[selectidx] .= true
        end

    end

    ## Add additional systems some templates had not enough systems
    ## (use systems with the highest score)
    if sum(selected) < n_select
        sas_ns = @view sas[.!selected]
        selected_ns = @view selected[.!selected]
        selectidx = sortperm(sas_ns, rev=true)[1:(n_select - sum(selected))]
        selected_ns[selectidx] .= true
    end

    filter(s -> s.properties["ID"] in IDs[selected], systems)
end
