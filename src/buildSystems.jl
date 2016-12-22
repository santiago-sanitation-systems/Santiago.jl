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
        println(io, " $(i[2].name) → ($(i[1].name)) → $(i[3].name)")
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
        num = push!(outs, c[1], -1) # not very elegant...
        if num == 0
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
        num = push!(ins, c[1], -1) # not very elegant...
        if num <= 0
            pop!(ins, c[1])
        end
    end
    return collect(keys(ins))
end



function is_complete(sys::System)
    length(get_outputs(sys)) == 0 &&
        length(get_inputs(sys)) == 0 # &&
    # any(length(t.outputs) == 0 for t in sys.techs) # check if at least one sink exist
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
    # filter(t -> !is_connected(t, sys), matching_techs) # Techs open inputs
    matching_techs
end


# -----------
# functions to find all systems

# Return a vector of Systems
function build_system!(sys::System, completesystems::Array{System}, deadendsystems::Array{System},
                       techs::Array{Tech}, n_tech_max::Int, resultfile::IO)

    if length(sys.techs) < n_tech_max
        # get matching Techs
        candidates = get_candidates(sys, techs)
        if length(candidates)==0
            # println("--- dead end ---")
            # println(sys)
            push!(deadendsystems, sys)
        end

        for candidate in candidates
            # extend systems
            sys_ext = extend_system(sys, candidate)
            for sysi in sys_ext
                if !(sysi in completesystems)
                    if sysi.complete
                        push!(completesystems, sysi)
                        println(resultfile, sysi)
                        flush(resultfile)
                    else
                        build_system!(sysi, completesystems, deadendsystems,
                                      techs, n_tech_max, resultfile)
                    end
                end
            end
        end
    end
end


"""
    Returns an Array of all possible `System`s starting with `source`. A source can be any technology with a least one output.
        """
function build_all_systems(source::Tech, techs::Array{Tech}, n_tech_max;
                           resultfile::IO=STDOUT)
    completesystems = System[]
    deadendsystems = System[]
    build_system!(System(source), completesystems, deadendsystems, techs, n_tech_max, resultfile)
    return completesystems, deadendsystems
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

    newsystems = System[]
    # add new a Tech
    for prodin in tech.inputs
        if prodin in sysout
            for last_tech in get_openout_techs(sys, prodin)
                # --- connection to new tech
                sysi = deepcopy(sys)
                push!(sysi.connections, (prodin, last_tech, tech)) # add new connection
                push!(sysi.techs, tech)

                sysi.complete = is_complete(sysi)
                push!(newsystems, sysi)

                # --- all possible connections
                connections = Connection[]
                # loops originating at tech
                for prodout in tech.outputs
                    techins = filter!(t -> t!=tech, get_openin_techs(sysi, prodout))
                    if tech.functional_group == :T
                        filter!(t -> t.functional_group!= :T, techins)
                    end
                    x = [(prodout, tech, t) for t in techins]
                    append!(connections, x)
                end

                # loops ending at tech
                for prodinopen in tech.inputs
                    techouts = get_openout_techs(sysi, prodinopen)
                    if tech.functional_group == :T
                        filter!(t -> t.functional_group!= :T, techouts)
                    end
                    x = [(prodinopen, t, tech) for t in techouts if t !=tech]
                    append!(connections, x)
                end

                # add all combinations of connections
                for con in Combinatorics.combinations(connections)
                    sysj = deepcopy(sysi)
                    for c in con
                        push!(sysj.connections, c)
                    end
                    sysj.complete = is_complete(sysj)
                    push!(newsystems, sysj)
                end
            end

        end
    end

    return newsystems
end
