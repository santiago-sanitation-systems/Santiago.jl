# -----------
# high level interface


export build_systems



"""
Returns the *names* of the `techs` that are not used in any of the `systems`
"""
function techs_not_used(systems::Vector{System}, techs::Vector{<:AbstractTech})
    tech_names = unique(Santiago.simplifytechname(t.name) for t in techs)
    techs_not_used_idx = fill(true, length(tech_names))
    for (i,t) in enumerate(tech_names)
        for s in systems
            techs_sys = (simplifytechname(ts.name) for ts in s.techs)
            if t ∈ techs_sys
                techs_not_used_idx[i] = false
                break
            end
        end
    end
    tech_names[techs_not_used_idx]
end


"""
# Build all systems from a given the sources and and a set of technologies.


```
build_systems(sources::Array{T},
              technologies::Array{T};
              additional_sources::Array{T}=T[]
              addlooptechs::Bool=true, looptechgroup=[:S, :T],
              max_candidates=10_000_000) where T <: AbstractTech
```
## Parameters
- sources:            An array of sources technologies
- technologies:       Array of sanitation technologies
- additional_sources: Array of source technolgies that are all added to the main sources (such as kitch sink)
- max_candidates:     The maximal number of system extensions that are tried.
                      A small number may lead to faster computations, but only to a random subset
                      of all possible systems in generated.

## Values
An array of all found sanitation systems.
"""
function build_systems(sources::Array{T},
                       technologies::Array{T};
                       additional_sources::Array{T}=T[],
                       addlooptechs::Bool=true, looptechgroup=[:S, :T],
                       max_candidates::Int=10_000_000) where T <: AbstractTech


    technologies2 = copy(technologies) # we do not want to modify the input array

    ## ------
    ## Generate looptechs

    if addlooptechs
        ninit = length(technologies2)
        add_loop_techs!(technologies2, groups = looptechgroup)
        @info "additional looped techs:\t$(lpad(length(technologies2) - ninit, 6))"
    end

    ## ------
    ## Generate each U with every Uadd

    src_comb = [[s; additional_sources] for s in sources]

    # dict with unique combination of input products
    d_source_combs = Dict{Array{Product}, Array{Array{T}}}()
    for sys in src_comb
        outs = get_outputs(sys)
        if haskey(d_source_combs, outs)
            push!(d_source_combs[outs], sys)
        else
            d_source_combs[outs] = [sys]
        end
    end

    if length(additional_sources) > 0
        @info "The $(length(sources)) sources and $(length(additional_sources)) additional sources are used."
    end

    allSys = System[]
    for source_products in keys(d_source_combs)
        io = IOBuffer()
        println(io, "Find systems for input (combination):\n  $(source_products)")
        println(io, "for the following source(s):")
        for s in d_source_combs[source_products]
            print(io, "- ")
            println(io, s)
        end
        @info String(take!(io))

        ## -----
        ## prefilter Techlist, returns sub_technologies
        ## sub_technologies contains technologies which do have only
        ## inputs that are generated with the current source.

        # sub_technologies = prefilterTechList(ss, sources, additional_sources, technologies2)
        sub_technologies = technologies2

        ## ---
        ## build systems

        ss = d_source_combs[source_products][1]
        newSys = build_all_systems(ss, sub_technologies; max_candidates=max_candidates)
        append!(allSys, newSys)

        ## ---
        ## if more sources with same intput products exists, simply swap sources

        for ss2 in d_source_combs[source_products][2:end]
            for sys in newSys
                s = System(sys, ss2)
                push!(allSys, s)
            end
        end


    end

    ## add a unique ID
    for s in allSys
        id_str = string(hash(s), base=62, pad=12)
        # separate string with '-' for better legibility
        id_str = replace(id_str, r"(.{4})" => s"\1-")
        id_str = replace(id_str, r"-$" => "")

        s.properties["ID"] = id_str
    end

    # add source names
    source_names!.(allSys)

    @info "Total number of systems (without duplicates): $(lpad(length(allSys), 6))"

    # check for not used techs
    t_no_used = techs_not_used(allSys, technologies)

    if length(t_no_used) == 0
        @info "All technologies have been used in at least one system"
    else
        msg_str = "The following technologies were not used in any system:\n"
        for t in t_no_used
            msg_str = msg_str * "- $(t)\n"
        end
        @info msg_str
    end

    return allSys
end
