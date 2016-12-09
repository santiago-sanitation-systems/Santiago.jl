module SanitationSystemBuilder

using AutoHashEquals

import DataStructures
import Combinatorics
import Base.show
import Base.getindex

export Tech, Product, System
export build_all_systems
export writedotfile

# -----------
# define types


@auto_hash_equals immutable Product
    name::Symbol
end

Product(name::String) = Product(Symbol(name))
show(io::Base.IO, p::Product) =  print("$(p.name)")

@auto_hash_equals immutable Tech
    inputs::Array{Product}
    outputs::Array{Product}
    name::String
    functional_group::Symbol
    n_inputs::Int
end

"""
The `Tech` type represents Technolgies.
It consist of `inputs`, `outputs`, a `name` and a `functional_group`.
"""
function Tech{T<:String}(inputs::Array{T}, outputs::Array{T}, name::T, functional_group::T)
    Tech([Product(x) for x in inputs],
	 [Product(x) for x in outputs],
	 name,
	 Symbol(functional_group),
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
A `Connection`is a Tuples{Product, sourceTech, sinkTech}.
"""
typealias Connection Tuple{Product, Tech, Tech}


"""
The `System` is an Array of Tuples{Product, Tech, Tech}.
"""
@auto_hash_equals type System
    techs::Set{Tech}
    connections::Set{Connection}
    complete::Bool
end

System(techs::Array{Tech}, con::Array{Connection}) = System(Set(techs), Set(con), false)
System(tech::Tech) = System(Set([tech]), Set(Connection[]), false)



function show(io::Base.IO, s::System)
    !s.complete ? print(io, "Incomplete ") : nothing
    println(io, "System with $(length(s.techs)) technologies and $(length(s.connections)) connections: ")
    for i in s.connections
        println(io, "$(i[1]) | $(i[2]) | $(i[3])")
    end
end


# -----------
# helper functions

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
    # all ins
    ins = DataStructures.counter(get_inputs(sys.techs))
    for c in sys.connections
        if haskey(ins, c[1])
            pop!(ins, c[1])
        end
    end
    return collect(keys(ins))
end



function is_complete(sys::System)
    length(get_outputs(sys)) == 0 && length(get_inputs(sys)) == 0
end


"""
Return all technologies of the system that have an open `prod` output
"""
function get_openout_techs(sys::System, prod::Product)

    function is_connected(tech, sys)
        for c in sys.connections
            if c[2] == tech && c[1] == prod
                return true
            end
        end
        return false
    end

    matching_techs = filter(t -> prod in t.outputs, sys.techs) # Techs with matching outputs
    filter(t -> !is_connected(t, sys), matching_techs) # Techs open outputs
end

"""
Return all technologies of the system that have an open `prod` input
"""
function get_openin_techs(sys::System, prod::Product)

    function is_connected(tech, sys)
        for c in sys.connections
            if c[3] == tech && c[1] == prod
                return true
            end
        end
        return false
    end

    matching_techs = filter(t -> prod in t.inputs, sys.techs) # Techs with matching inputs
    filter(t -> !is_connected(t, sys), matching_techs) # Techs open outputs
end


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

    for candidate in candidates
        # extend systems
        sys_ext = extend_system(sys, candidate)
        for sysi in sys_ext
            if sysi.complete
                push!(completesystems, sysi)
                # println(resultfile, sysi)
                # flush(resultfile)
            else
                build_system!(sysi, completesystems, techs, resultfile, errorfile)
            end
        end
    end
end

"""
    Returns an Array of all possible `System`s starting with `source`. A source can be any technology with a least one output.
    """
function build_all_systems(source::Tech, techs::Array{Tech};
                           resultfile::IO=STDOUT, errorfile::IO=STDERR)
    completesystems = System[]
    build_system!(System(source), completesystems, techs, resultfile, errorfile)
    return unique(completesystems)
end


# Returns techs that fit to an open system
function get_candidates(sys::System, techs::Array{Tech})

    techssub = filter(t -> !(t in sys.techs), techs)
    outs = get_outputs(sys)

    # is a match if any input matchs an open output
    function ff(t)
        for i in t.inputs
            if i in outs
                return(true)
            end
        end
        false
    end

    filter(ff, techssub)
end



"""
    Return an array of all possible extension of `sys` with the candidate technology
    """
function extend_system(sys::System, tech::Tech)

    sysout = get_outputs(sys)
    push!(sys.techs, tech)

    newsystems = System[]
    # add new a Tech
    for prodin in tech.inputs
        if prodin in sysout
            for last_tech in get_openout_techs(sys, prodin)
                # --- connection to new tech
                sysi = deepcopy(sys)
                push!(sysi.connections, (prodin, last_tech, tech)) # add new connection

                sysi.complete = is_complete(sysi)
                push!(newsystems, sysi)

                # --- all possible connections
                connections = Tuple{Product,Tech, Tech}[]
                # loops originating at tech
                for prodout in tech.outputs
                    techins = get_openin_techs(sys, prodout)
                    x = [(prodout, tech, t) for t in techins]
                    append!(connections, x)
                end
                # loops ending at tech
                for prodinopen in filter(x -> x!=prodin, tech.inputs)
                    techouts = get_openout_techs(sysi, prodinopen)
                    x = [(prodinopen, t, tech) for t in techouts]
                    append!(connections, x)
                end

                # add all combinations of connections
                for con in Combinatorics.combinations(connections)
                    sysj = deepcopy(sysi)
                    for c in con
                        push!(sysj.connections, c)
                        sysj.complete = is_complete(sysj)
                        push!(newsystems, sysj)
                    end
                end

            end
        end
    end
    return newsystems
end

function close_loops(sys::System, tech::Tech)
    open_prod = tech.outputs

    # all possible connections
    connections = Tuple{Product,Tech, Tech}[]
    for prodout in tech.outputs
        techins = get_openin_techs(sys, prodout)
        x = [(prodout, tech, t) for t in techins]
        append!(connections, x )
    end

    # add connections
    for con in Combinatorics.combinations(connections)
        sysi = deepcopy(sys)
        for c in con
            push!(sysi.connections, c)
            push!(newsystems, sysi)
        end
    end
end

# ---------------------------------
# write dot file for visualisation with grapgviz

"""Writes a DOT file of a `System`. The resulting file can be visualized with GraphViz, e,g.:
        ```
        dot -Tpng file.dot -o graph.png
        ```
        """
function writedotfile(sys::System, file::String, options::String="")
    open(file, "w") do f
        println(f, "digraph system {")
        if options!=""
            println(f, "$(options);")
        end
        # define nodes
        for t in vcat(sys.techs...)
            println(f, replace("$(t.name) [shape=box, label=\"$(t.name)\"];", ".", "_"))
        end
        # edges
        for c in sys.connections
            println(f, replace("$(c[2].name) -> $(c[3].name) [label=\"$(c[1].name)\"];", ".", "_"))
        end
        println(f, "}")
    end
end



end # module
