# -----------
# high level interface


export santiago_build_systems


"""
# Build all systems from a given the sources and and a set of technologies.


```
santiago_build_systems(sources::Array{T},
                      technologies::Array{T};
                      additional_sources::Array{T}=T[]
                      addlooptechs::Bool=true, looptechgroup=[:S, :T]) where T <: AbstractTech
```
## Parameters
- sources:            An array of sources technologies
- technologies:       Array of sanitation technologies
- additional_sources: optional array of source technolgies that can be added to the main sources (such as kitch sink)

## Values
An array of all found sanitation systems.
"""
function santiago_build_systems(sources::Array{T},
                                technologies::Array{T};
                                additional_sources::Array{T}=T[],
                                addlooptechs::Bool=true, looptechgroup=[:S, :T]) where T <: AbstractTech

    ## ------
    ## Generate looptechs
    if addlooptechs & length(additional_sources)>1
        # build looped techs
        ninit = nold = length(technologies)
        add_loop_techs!(technologies, groups = looptechgroup)
        i = 1
        while nold < length(technologies) & i < 2
            nold = length(technologies)
            add_loop_techs!(technologies, groups = looptechgroup)
            i += 1
        end
        @info "$(length(technologies) - ninit) looped techs added."
    end

    ## ------
    ## Generate Combinations of U and Uadd

    src_comb = vcat([generateCombinations(src, additional_sources) for src in sources]...)
    @debug "$(length(src_comb)) source combinations found."

    allSys = System[]
    for ss in src_comb

        ## -----
        ## prefilter Techlist, returns sub_technologies
        ## sub_technologies contains technologies which do have only
        ## inputs that are generated with the current source.

        sub_technologies = prefilterTechList(ss, sources, additional_sources, technologies)

        # get source name
        names_ss = []
        for s in ss
            push!(names_ss, s.name)
        end
        names_ss = names_ss[end:-1:1]
        names_ss = join(names_ss, "_")

        ## ---
        ## build systems

        newSys = build_all_systems(ss, sub_technologies)

        # store source name
        for s in newSys
            s.properties["source"] = names_ss
        end
        append!(allSys, newSys)
    end

    ## add ID
    for (i,s) in enumerate(allSys)
        s.properties["ID"] = i
    end

    return allSys
end
