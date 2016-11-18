module SanitationSystemBuilder

import Combinatorics
import Base.show

export Tech, System
export build_all_systems
export writedotfile

# -----------
# define types

immutable Tech
    inputs::Array{Symbol}
    outputs::Array{Symbol}
    name::String
    tech_group::Symbol
    n_inputs::Int
end

"""
The `Tech` type represents Technolgies.
    It consist of `inputs`, `outputs`, a `name` and a `tech_group`.
    """
function Tech{T<:String}(inputs::Array, outputs::Array, name::T, tech_group::T)
    Tech(Symbol[Symbol(x) for x in inputs],
	 Symbol[Symbol(x) for x in outputs],
	 name,
	 Symbol(tech_group),
	 size(inputs,1))
end


"System is simply an Array of Arrays of Technologies"
type System
    techs::Array{Array{Tech}}
end


# Functions for pretty printing
function show(io::Base.IO, t::Tech)
    instr = length(t.inputs) >0 ? t.inputs : ["Source"]
    outstr = length(t.outputs) >0 ? t.outputs : ["Sink"]
    print(io, "$(t.name): ($(join(instr, ", "))) -> ($(join(outstr, ", "))) ")
end

function show(io::Base.IO, s::System)
    print(io, "System with $(length(vcat(s.techs...))) technologies: ")
    for i in s.techs
        show(io, i)
    end
end



# -----------
# functions to find all systems

# Return a vector of Systems
function build_system!(sys::System, completesystems::Array{System}, techs::Array{Tech},
		       resultfile::IO, errorfile::IO)
    next = get_matching(sys.techs[end], techs)

    if length(next)==0
        print(errorfile, "dead end!: ")
        println(errorfile, sys)
        flush(errorfile)
    end

    sys_names = get_tech_group(sys)
    for n in next
        if length(findin(sys_names, get_tech_group(n)))==0 # check if no duplicates
            sysi = deepcopy(sys)
            push!(sysi.techs, n)
            if length(get_outputs(n))==0      # all sinks
                push!(completesystems, sysi)
                println(resultfile, sysi)
                flush(resultfile)
            else
                build_system!(sysi, completesystems, techs, resultfile, errorfile)
            end
        end
    end
end

"""
    Returns an Array of all possible `System`s starting with `source`. A source can be any technology with a least one output."""
function build_all_systems(source::Tech, techs::Array{Tech};
			   resultfile::IO=STDOUT, errorfile::IO=STDERR)
    completesystems = System[]
    build_system!(System(Array[[source]]), completesystems, techs, resultfile, errorfile)
    return completesystems
end


# Returns techs that fit to a system part
function get_matching(s::Array{Tech}, techs::Array{Tech})
    ## all outgoing streams
    outs = get_outputs(s)
    matches = Array{Array{Tech},1}()
    n_out = length(outs)
    ## get matching combinations
    for k in 1:n_out
        for c in Combinatorics.combinations(get_candidates(techs, outs, k), k) # try all combination of lenght k (in R: combn())
            inputs = get_inputs(c)
            if is_compatible(outs, inputs)
                push!(matches, c)
            end

        end
    end
    return matches
end

# test if outputs are compatible with next inputs.
function is_compatible(outputs, inputs)
    sort(outputs) == sort(inputs)         # no empty inputs allowed
    # sort(outputs) == sort(unique(inputs)) # empty inputs allowed possible
end

# little helpers
function get_inputs(s::Array{Tech})
    inputs = []
    for t in s
        append!(inputs, t.inputs)
    end
    return inputs
end


function get_outputs(s::Array{Tech})
    outs = []
    for t in s
        append!(outs, t.outputs)
    end
    return outs
end

function get_tech_group(s::System)
    names = Symbol[]
    for t in vcat(s.techs...)
        push!(names, t.tech_group)
    end
    return names
end


function get_tech_group(s::Array{Tech})
    names = Symbol[]
    for t in s
        push!(names, t.tech_group)
    end
    return names
end


# pre filter the tech list
function get_candidates(s::Array{Tech}, outs, k)

    n_out = length(outs)
    n_in_min = k==1? n_out : 1
    n_in_max = n_out - k +1

    function condi(t::Tech)
        issubset(t.inputs, outs) &&  (n_in_min <= t.n_inputs <= n_in_max)
    end

    filter(condi, s)
end



# ---------------------------------
# write dot file for visualisation with grapgviz

"Writes a DOT file of a `System`. The resulting file can be visualized with GraphViz, e,g.:
```
dot -Tpng file.dot -o graph.png
````
"
function writedotfile(sys::System, file::AbstractString)
    open(file, "w") do f
        println(f, "digraph system {")
        # define nodes
        for t in vcat(sys.techs...)
            println(f, replace("$(t.name) [shape=box, label=\"$(t.tech_group)\"];", ".", "_"))
        end
        # edges
        for g in 1:size(sys.techs, 1)-1
            for t in sys.techs[g]
                for out in t.outputs
                    n = filter(x -> length(findin([out], x.inputs))>0,
	                       sys.techs[g+1])
                    println(f, replace("$(t.name) -> $(n[1].name) [label=\"$(out)\"];", ".", "_"))
                end
            end
        end
        println(f, "}")
    end
end



end # module
