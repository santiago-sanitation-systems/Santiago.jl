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
	appscore::Float64
    n_inputs::Int
end

"""
The `Tech` type represents Technolgies.
It consist of `inputs`, `outputs`, a `name` and a `functional_group`.
"""
function Tech{T<:String}(inputs::Array{T}, outputs::Array{T}, name::T, functional_group::T, appscore::Float64)
    Tech([Product(x) for x in inputs],
	 [Product(x) for x in outputs],
	 name,
	 Symbol(functional_group),
	 appscore,
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
System(techs::Array{Tech}) = System(Set(techs), Set(Connection[]), false)



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
                       techs::Array{Tech}, islegal::Function, resultfile::IO, print_prog::Bool, hashset::Set{UInt64})

    # get matching Techs
    candidates = get_candidates(sys, techs)
    #if length(candidates)==0
        # println("--- dead end ---")
        # println(sys)
        #push!(deadendsystems, sys)
    #end
	
    for candidate in candidates
        # extend systems
        sys_ext = extend_system(sys, candidate)
		
        for sysi in sys_ext
		
            if sysi.complete && !(sysi in completesystems)
                push!(completesystems, sysi)
                println(resultfile, sysi)
                flush(resultfile)
            elseif !sysi.complete && islegal(sysi) && !(hash(sysi) in hashset)
				push!(hashset, hash(sysi))
				!print_prog || print(".")
                build_system!(sysi, completesystems, deadendsystems,
                            techs, islegal, resultfile, false, hashset)
            end
            
		end
    end
end


"""
    Returns an Array of all possible `System`s starting with `source`. A source can be any technology with a least one output.
"""
function build_all_systems(source::Array{Tech}, techs::Array{Tech}; islegal::Function=x -> true,
                           resultfile::IO=STDOUT)
    completesystems = System[]
    deadendsystems = System[]
    build_system!(System(source), completesystems, deadendsystems, techs, islegal, resultfile, true, Set{UInt64}())
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
					# Loops to last_tech are forbidden, if the functional group is different.
					filter!(t -> (t.name != last_tech.name || t.functional_group == tech.functional_group), techins)
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

"""
    Return an array possible Technologies (Sub Array of techlist) for the given Sources.
	number of technologies is reduced by removing Techs that require an input that is not available with 
	the sources provided.
"""
function prefilterTechlist(currentSources::Array{Tech}, sources::Array{Tech}, sourcesAdd::Array{Tech}, tech_list::Array{Tech})
	
	# All Products that can be created by available sources
	otherSourcesProduct = vcat([t.outputs for t in sources]...)
	otherSourcesAddProduct = vcat([t.outputs for t in sourcesAdd]...)
	append!(otherSourcesProduct, otherSourcesAddProduct)
	
	# Outputs of all the used Sources
	output_list = Product[]
	for ss_c in ss
		append!(output_list, ss_c.outputs)
	end
	
	otherSourcesProduct = filter(x -> !(x in output_list), otherSourcesProduct)
	otherSourcesProduct = map(x -> "$(x.name)", otherSourcesProduct) # convert to Strings
	
	# Additional Filter. REMOVE HARD CODING OF PRODUCT NAMES
	for tproduct in otherSourcesProduct
		if tproduct == "excreta"
			append!(otherSourcesProduct, ["pithumus"])
		end
	end

	# check of any the String in otherSourcesProduct is part of an input products name
	function ffilter(x)
		inputs = map(x -> "$(x.name)", x.inputs)
		match_inputs = filter(Regex(join(otherSourcesProduct, '|')), inputs)
		length(match_inputs) == 0
	end

	sub_tech_list = filter(ffilter, tech_list)
	
	return sub_tech_list
end