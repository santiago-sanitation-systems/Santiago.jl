module SanitationSystemBuilder

import DataStructures
import Combinatorics
import Base.show
import Base.getindex

export Tech, Product, System
export build_all_systems
export writedotfile

# -----------
# define types


immutable Product
    name::Symbol
end

Product(name::String) = Product(Symbol(name))
show(io::Base.IO, p::Product) =  print("$(p.name)")

immutable Tech
    inputs::Array{Product}
    outputs::Array{Product}
    name::String
    tech_group::Symbol
    n_inputs::Int
end

"""
    The `Tech` type represents Technolgies.
        It consist of `inputs`, `outputs`, a `name` and a `tech_group`.
        """
function Tech{T<:String}(inputs::Array{T}, outputs::Array{T}, name::T, tech_group::T)
    Tech([Product(x) for x in inputs],
	 [Product(x) for x in outputs],
	 name,
	 Symbol(tech_group),
	 size(inputs,1))
end


# Functions for pretty printing
function show(io::Base.IO, t::Tech)
    instr = ["$(ii.name)" for ii in t.inputs]
    outstr = ["$(ii.name)" for ii in t.outputs]
    instr = length(instr) >0 ? instr : ["Source"]
    outstr = length(outstr) >0 ? outstr : ["Sink"]
    print(io, "$(t.name): ($(join(instr, ", "))) -> ($(join(outstr, ", ")))")
end


"""
    The `System` is an Array of Tuples{Product, Tech, Tech}.
        """
type System
    techs::Set{Tech}
    connections::Array{Tuple{Product, Tech, Tech}}
    complete::Bool
end

System(techs::Array{Tech}, con::Array{Tuple{Product, Tech, Tech}}) = System(Set(techs), con, false)



function show(io::Base.IO, s::System)
    !s.complete ? print(io, "Incomplete ") : nothing
    println(io, "System with $(length(s.techs)) technologies and $(length(s.connections)) connections: ")
    for i in s.connections
        println(io, "$(i[1]) | $(i[2]) | $(i[3])")
    end
end

# -----------
# functions to find all systems

function get_outputs{T<:Union{Array{Tech}, Set{Tech}}}(techs::T)
    outs = Product[]
    for t in techs
        append!(outs, t.outputs)
    end
    return outs
end

"""
return all "open" outputs of a system
"""
function get_outputs(sys::System)
    # all outs
    outs = DataStructures.counter(get_outputs(sys.techs))

    for c in sys.connections
        if haskey(outs, c[1])
            pop!(outs, c[1])
        end
    end
    return collect(keys(outs))
end


function get_inputs{T<:Union{Array{Tech}, Set{Tech}}}(techs::T)
    ins = Product[]
    for t in techs
        append!(ins, t.inputs)
    end
    return ins
end

"""
return all "open" inputs of a system
"""
function get_inputs(sys::System)
    # all outs
    ins = DataStructures.counter(get_inputs(sys.techs))

    for c in sys.connections
        if haskey(ins, c[1])
            pop!(ins, c[1])
        end
    end
    return collect(keys(ins))
end


# -----------
# functions to find all systems

# candidates = Dict{Product, Set{Tech}}()


# for t in techs
#     for i in t.inputs
#         candidates[i] = t
#     end
# end



# -----------
# functions to find all systems

# Return a vector of Systems
function build_system!(sys::System, completesystems::Array{System}, techs::Array{Tech},
                       resultfile::IO, errorfile::IO)

    # get matching Techs
    candidates = get_candidates(sys, techs)

    # if length(candidates)==0
    #     print(errorfile, "dead end!: ")
    #     println(errorfile, sys)
    #     flush(errorfile)
    # end

    sys_names = get_tech_group(sys)

    for candidate in candidates
        if length(findin(sys_names, get_tech_group(n)))==0 # check if no duplicates
            sysi = deepcopy(sys)

            # extend system
            sysi = extend_system(sys, candidate)

            if sysi.complete
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
function get_candidates(sys::System, techs::Array{Tech})
    outs = get_outputs(sys)
    open_inputs
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
    n_in_max = n_out - k + 1

    function condi(t::Tech)
        issubset(t.inputs, outs) && (n_in_min <= t.n_inputs <= n_in_max)
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
function writedotfile(sys::System, file::AbstractString, options::AbstractString="")
    open(file, "w") do f
        println(f, "digraph system {")
        if options!=""
            println(f, "$(options);")
        end
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
