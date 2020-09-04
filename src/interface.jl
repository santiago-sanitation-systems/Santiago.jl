# -----------
# high level interface


export build_systems


"""
# Build all systems from a given the sources and and a set of technologies.


```
build_systems(sources::Array{T},
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
function build_systems(sources::Array{T},
                       technologies::Array{T};
                       additional_sources::Array{T}=T[],
                       addlooptechs::Bool=true, looptechgroup=[:S, :T]) where T <: AbstractTech


    technologies2 = copy(technologies) # we do not want to modify the inputs

    ## ------
    ## Generate looptechs
    if addlooptechs
        # build looped techs
        ninit = nold = length(technologies2)
        add_loop_techs!(technologies2, groups = looptechgroup)
        i = 1
        while nold < length(technologies2) & i < 2
            nold = length(technologies2)
            add_loop_techs!(technologies2, groups = looptechgroup)
            i += 1
        end
        @debug "$(length(technologies2) - ninit) looped techs added."
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

        # sub_technologies = prefilterTechList(ss, sources, additional_sources, technologies2)
        sub_technologies = technologies2

        # get source name
        names_ss = String[]
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
