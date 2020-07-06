using AutoHashEquals

import DataStructures
import Combinatorics
import Base.show
import Base.getindex
import Base.copy
import Base.==
import Base.isless
import Base.hash
import StatsBase


export AbstractTech, Tech, TechCombined, Product, System


# -----------
# define types


@auto_hash_equals struct Product
name::Symbol
end

Product(name::T) where T <: AbstractString = Product(Symbol(name))
show(io::Base.IO, p::Product) = print(io, "$(p.name)")

isless(p1::Product, p2::Product) = isless(p1.name, p2.name)

Broadcast.broadcastable(p::Product) = Ref(p)

abstract type AbstractTech end

@auto_hash_equals struct Tech <: AbstractTech
    inputs::Array{Product}
    outputs::Array{Product}
    name::String
    functional_group::Symbol
    appscore::Array{Float64}
    n_inputs::Int
    transC::Dict{String, Dict{Product, Float64}}
    transC_reliability::Dict{String, Float64}
end

const Source = Tech
const Sink = Tech


function Tech(inputs::Array{Product}, outputs::Array{Product},
              name::String, functional_group::Symbol,
              appscore::Float64, n_inputs::Int,
              transC::Dict{String, Dict{Product, Float64}},
              transC_reliability::Dict{String, Float64})
    Tech(inputs, outputs,
         name, functional_group,
         Float64[appscore],
         n_inputs,
         transC, transC_reliability)
end


"""
The `Tech` type represents Technolgies.
It consist of `inputs`, `outputs`, a `name`, a `functional_group`, and a transfer coefficients `transC`.
"""
function Tech(inputs::Array{T}, outputs::Array{T}, name::T, functional_group::T,
              appscore::Float64,
              transC::Dict{String, Dict{Product, Float64}},
              transC_reliability::Dict{String, Float64}) where T<:String

    # sanity check
    for sub in keys(transC)
        s = 0.0
        for val = values(transC[sub])
            s += val
        end
        if !isapprox(s, 1.0)
            error("Tech $(name): The transfer coefficients for $sub do not sum to 1!")
        end
    end


    Tech([Product(x) for x in inputs],
         [Product(x) for x in outputs],
         name,
         Symbol(functional_group),
         appscore,
         size(inputs,1),
         transC,
         transC_reliability)
end


# Functions for pretty printing
function show(io::Base.IO, t::AbstractTech)
    instr = ["$(ii.name)" for ii in t.inputs]
    outstr = ["$(ii.name)" for ii in t.outputs]
    instr = length(instr) >0 ? instr : ["Source"]
    outstr = length(outstr) >0 ? outstr : ["Sink"]
    print(io, "$(t.name): ($(join(instr, ", "))) -> ($(join(outstr, ", ")))")
end


"""
A `Connection`is a Tuples{Product, sourceTech, sinkTech}.
"""
const Connection = Tuple{Product, AbstractTech, AbstractTech}


"""
Type of combined (looped) Techs.
"""
@auto_hash_equals struct TechCombined <: AbstractTech
    inputs::Array{Product}
    outputs::Array{Product}
    name::String
    functional_group::Symbol
    appscore::Array{Float64}
    n_inputs::Int
    internal_techs::Set{Tech}
    internal_connections::Set{Connection}
end



"""
A `System` consists of `techs` and `conncetions`.
"""
mutable struct System
    techs::Set{AbstractTech}
    connections::Set{Connection}
    complete::Bool
    properties::Dict
end

# ignore properties for isequal
Base.hash(sys::System, h::UInt) = hash(sys.techs, hash(sys.connections, hash(sys.complete, hash(:System, h))))
Base.:(==)(a::System, b::System) = isequal(a.techs, b.techs) && isequal(a.connections, b.connections) && isequal(a.complete, b.complete) && true

System(techs::Set{T}, con::Set{Connection}, complete::Bool) where T <: AbstractTech = System(techs, con, complete, Dict())
System(techs::Array{T}, con::Array{Connection}, complete::Bool)  where T <: AbstractTech = System(Set(techs), Set(con), complete)
System(techs::Array{T}, con::Array{Connection}) where T <: AbstractTech = System(Set(techs), Set(con), false)
System(techs::Array{T})  where T <: AbstractTech = System(Set(techs), Set(Connection[]), false)


# Function to copy a System
function copy(sys::System)
    System(copy(sys.techs), copy(sys.connections), copy(sys.complete))
end


function show(io::Base.IO, s::System)
    !s.complete ? print(io, "Incomplete ") : nothing
    println(io, "System with $(length(s.techs)) technologies and $(length(s.connections)) connections: ")
    for i in s.connections
        println(io, " $(i[2].name) → ($(i[1].name)) → $(i[3].name)")
    end
end


# -----------
# helper functions

function get_outputs(techs::T2) where T2<:Union{Array{T1}, Set{T1}}  where T1<:AbstractTech
    outs = Product[]
    for t in techs
        append!(outs, t.outputs)
    end
    return outs
end

"""
returns all "open" outputs of a system

A dic
"""
function get_outputs(sys::System)
    # all outs
    outs = get_outputs(sys.techs)

    for c in sys.connections

        idx = findall(outs .== c[1]) # get index of appl products mathing c
        deleteat!(outs, idx[1])   # remove one product
    end
    return outs
end

function get_inputs(techs::T2) where T2<:Union{Array{T1}, Set{T1}} where T1<:AbstractTech
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
            DataStructures.reset!(ins, c[1])
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

    matching_techs = filter(t -> prod in t.outputs, sys.techs) # Techs with matching outputs			# SLOW
    filter(t -> !is_connected(t, sys), matching_techs) # Techs open outputs				        # SLOW
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

# pre filter the tech list
function get_candidates(s::Array{T}, outs, k) where T <: AbstractTech
    # Limitation!
    # This function guaranties, that we never add a techs, which leads to new open inputs.
    # However, this banns not only loops, but also "triangles". E.g if only "A is given"
    #   A ---> B
    #    \    ^
    #     \  /
    #      >C
    # this system cannot be found! Because B, C are on the same stage
    # of the algorithm. (Exception: both inputs of B have the same product)
    n_out = length(outs)
    n_in_max = n_out - k + 1
    function condi(t::AbstractTech)
        issubset(t.inputs, outs) && (t.n_inputs <= n_in_max)

    end

    filter(condi, s)
end


# -----------
# functions to find all systems

# Return a vector of Systems
function build_system!(sys::System, completesystems::Array{System},
                       techs::Array{T}, islegal::Function,
                       logfile::IO, hashset::Set{UInt64}, threadlock) where T <: AbstractTech

    # get Array of matching Techs Arrays
    candidates = get_candidates(sys, techs)

    Base.Threads.@threads for candidate in candidates
        # extend systems
        sys_exts = extend_system(sys, candidate) # Do we need a lock for 'sys'???
        for sys_ext in sys_exts
            if sys_ext.complete
                lock(threadlock) do
                    if !(sys_ext in completesystems)
                        push!(completesystems, sys_ext)
                    end
                    @info "$sys_ext"
                end
            elseif !sys_ext.complete && islegal(sys_ext) && !(hash(sys_ext) in hashset)
                lock(threadlock) do
                    push!(hashset, hash(sys_ext))
                end
                build_system!(sys_ext, completesystems,
                              techs, islegal, logfile, hashset, threadlock)
            end
        end
    end
end


"""
Returns an Array of all possible `System`s starting with `source`. A source can be any technology with a least one output.
"""
function build_all_systems(source::Array{T1}, techs::Array{T2};
                           islegal::Function=x -> true,
                           logfile=stdout) where T1 <: AbstractTech where T2 <: AbstractTech

    completesystems = System[]
    threadlock = ReentrantLock()
    build_system!(System(source), completesystems, techs, islegal,
                  logfile, Set{UInt64}(), threadlock)


    # split TechCombineds
    split_techcombined!.(completesystems)
    completesystems = unique(completesystems) # before split techs system are different but once splitted they are identical (e.g. due to permuations of some techs in two combitechs)
    return completesystems
end


# replace combined techs with seperate internal techs
function split_techcombined!(sys)

    combtechs = filter(t -> typeof(t) == TechCombined, sys.techs)

    # remove TechCombineds
    filter!(t -> typeof(t) != TechCombined, sys.techs)

    # remove connection to/from TechCombineds
    allConn_TechCombs = filter(c -> any(occursin.("::", [c[2].name, c[3].name])),
                               sys.connections)
    filter!(c -> !(c in allConn_TechCombs), sys.connections)

    # add internal techs/connections
    for t in combtechs
            union!(sys.techs, t.internal_techs)
            union!(sys.connections, t.internal_connections)
    end

    # add connection from/to internal techs
    for c in allConn_TechCombs
        prod, from_tech, to_tech = c
        if occursin("::", from_tech.name)

            int_con_prod = collect(filter(c -> c[1] == prod, from_tech.internal_connections))
            ffilter = function (t::AbstractTech)
                prod in t.outputs &&
                    !any(getindex.(int_con_prod, 2) == t)
            end

            from_tech = collect(filter(ffilter, from_tech.internal_techs))
        end
        if occursin("::", to_tech.name)

            int_con_prod = collect(filter(c -> c[1] == prod, to_tech.internal_connections))
            ffilter = function (t::AbstractTech)
                prod in t.inputs &&
                    !any(getindex.(int_con_prod, 3) == t)
            end

            to_tech = collect(filter(ffilter, to_tech.internal_techs))
        end

       if ! (typeof(from_tech) <: AbstractArray)
           from_tech = [from_tech]
       end
       if ! (typeof(to_tech) <: AbstractArray)
           to_tech = [to_tech]
       end
        for ft in [from_tech...]
            for tt in [to_tech...]
               push!(sys.connections, (prod, ft, tt))
            end
        end
    end
end


# converts a vecptr of TEchs and techsCombined to a purly Tech array
function meltTechs(techs::Union{Array{T}, Set{T}}) where T <: AbstractTech
    flattechs = Tech[]
    for t in techs
        if typeof(t)==Tech
            push!(flattechs, t)
        else
            append!(flattechs, t.internal_techs)
        end
    end
    return flattechs
end



# Returns techs that fit to an open system
function get_candidates(sys::System, techs::Array{T}) where T <: AbstractTech

    # filter out already used techs (also in TechCombined)
    systechs = meltTechs(sys.techs)
    ffilter(t::Tech) = !(t in systechs)
    ffilter(t::TechCombined) = length(intersect(t.internal_techs, systechs)) == 0
    techssub = filter(t -> ffilter(t), techs)

    outs = get_outputs(sys)

    matching_techs = Array{Array{AbstractTech},1}()
    n_out = length(outs)

    ## get matching combinations
    for k in 1:n_out
        for c in Combinatorics.combinations(get_candidates(techssub, outs, k), k) # try all combination of lenght k (in R: combn())
            inputs = get_inputs(c)
            if is_compatible(outs, inputs)
                push!(matching_techs, c)
            end

        end
    end

    ## check that no matching combination has dublicated Techs (e.g. not ok: [A, A::B])
    function filterdublicates(m)
        m_flat = meltTechs(m)
        length(m_flat) == length(unique(m_flat))
    end
    filter!(filterdublicates, matching_techs)

    return matching_techs
end


# test if outputs are compatible with next inputs.
function is_compatible(outputs, inputs)
    outputs = DataStructures.counter(outputs)
    inputs = DataStructures.counter(inputs)

    # check if outputs and inputs are compatible
    if length(setdiff(keys(outputs), keys(inputs))) != 0
        return false
    end

    # exclude spliting of one output to multiple inputs
    for prod in keys(outputs)
        if outputs[prod] < inputs[prod]
            return false
        end
    end
    return true
end

#-----------------------------------------------------
# helper for extend_system

"""
return all variation how sys can be extended with tech_comb
"""
function make_connections!(part_sys::Array{System}, extended_sys::Array{System})
    for s in part_sys
        if length(get_inputs(s)) == 0 # check if more connections must be added
            if is_complete(s) # check if the whole system is complete
                s.complete = true
            end
            push!(extended_sys, s)
        else
            part_sys_new = add_next_connection(s)
            make_connections!(part_sys_new, extended_sys)
        end
    end
end

"""
helper to add connections for the next product
"""
function add_next_connection(sys::System) # sys is the combination of the initial sys and tech_comb
    new_part_sys = System[]

    # select first open input product
    p = get_inputs(sys)[1]
    in_techs = get_openin_techs(sys, p)
    out_techs = get_openout_techs(sys, p)
    setdiff!(out_techs, in_techs) # to avoid looping back to the same tech
    # has additional benefit of finding loops between techs of tech_comb in case
    # of an output of one tech from tech_comb is part of the set of "open inputs"
    n = length(out_techs)
    if n > 0
        for connection_combs in Base.product(Base.Iterators.repeated(in_techs, n)...)
            if length(unique(connection_combs)) == length(in_techs) # no empty input techs allowed / all in_techs must be used
                sysi = copy(sys)
                for (i, out_tech) in enumerate(out_techs)
                    push!(sysi.connections, (p, out_tech, connection_combs[i])) # add new connection between out_techs and the combinations of in_techs for product p
                end
                push!(new_part_sys, sysi)
            end
        end
    end
    return new_part_sys
end

"""
Return an array of all possible extension of `sys` with the candidate technology
"""
function extend_system(sys::System, tech_comb::Array{T}) where T <: AbstractTech

    sysi = copy(sys)
    union!(sysi.techs, tech_comb)
    extended_sys = System[]
    make_connections!([sysi], extended_sys)

    return extended_sys
end


"""
Return an array possible Technologies (subset of techlist) for the given Sources.
The number of technologies is reduced by removing Techs that require an input that is not available with
the sources provided.
"""
function prefilterTechList(currentSources::Array{T1}, sources::Array{T2},
                           sourcesAdd::Array{T2}, tech_list::Array{T2}) where T1 <: AbstractTech where T2 <: AbstractTech

    # All Products that can be created by available sources
    otherSourcesProduct = vcat([t.outputs for t in sources]...)
    otherSourcesAddProduct = vcat([t.outputs for t in sourcesAdd]...)
    append!(otherSourcesProduct, otherSourcesAddProduct)

    # Outputs of all the used Products by current Source
    output_list = Product[]
    for ss_c in currentSources
        append!(output_list, ss_c.outputs)
    end

    otherSourcesProduct = filter(x -> !(x in output_list), otherSourcesProduct)
    otherSourcesProduct = map(x -> "$(x.name)", otherSourcesProduct) # convert to Strings
    push!(otherSourcesProduct, "^[.]") # this is a dummy patter to ensure that filter works if otherSourcesProduct is empty

    # check that non of the String in otherSourcesProduct is part of an input products name
    function ffilter(x)
        inputs = map(x -> "$(x.name)", x.inputs)
        all(.!occursin.(Regex(join(otherSourcesProduct, '|')), inputs))
    end

    sub_tech_list = filter(ffilter, tech_list)

    return sub_tech_list
end



"""
add tech combinations with internal loops. Only for techs in group :S and :T
"""
function add_loop_techs!(tech_list::Array{AbstractTech}; groups = [:S, :T])
    for fgroup in groups
        tech_list_group = filter(t -> t.functional_group == fgroup, tech_list)
        for tech1 in tech_list_group
            for tech2 in tech_list_group
                if tech1 != tech2

                    outs1 = tech1.outputs
                    outs2 = tech2.outputs
                    ins1 = tech1.inputs
                    ins2 = tech2.inputs
                    exchange_1_2 = intersect(outs1, ins2)
                    exchange_2_1 = intersect(outs2, ins1)
                    if (length(exchange_1_2) >= 1 | length(exchange_2_1) >= 1) && length(intersect(exchange_1_2, exchange_2_1))==0 &&
                        length(intersect(ins1, ins2)) == 0
                        # matching tech are partners!
                        tech_news = make_looped_techs(tech1, tech2)
                        for tech_new in tech_news
                            if !(tech_new in tech_list) && length(tech_new.outputs)>0 && length(tech_new.inputs)>0
                                push!(tech_list, tech_new)
                            end
                        end
                    end
                end
            end
        end
    end
end


function make_looped_techs(tech1::Tech, tech2::Tech)

    # input_new = union(in1, in2) - intersect(out1, in2) - intersect(out2, in1)
    # output_new = union(out1, out2) - intersect(out1, in2) - intersect(out2, in1)

    inputs = DataStructures.counter(vcat(tech1.inputs, tech2.inputs))
    outputs = DataStructures.counter(vcat(tech1.outputs, tech2.outputs))

    internal_12 = DataStructures.counter(vcat(intersect(tech1.outputs, tech2.inputs)))
    internal_21 = DataStructures.counter(vcat(intersect(tech2.outputs, tech1.inputs)))

    internal_products = [collect(keys(internal_12)), collect(keys(internal_21))]

    # --- remove internal connections for new tech ins and outs
    # reduce counter
    for p in keys(merge(internal_12, internal_21))
        push!(inputs, p, -1)
        push!(outputs, p, -1)
    end
    # remove all products that occure 0 times
    ins = Product[p[1] for p in inputs if p[2]>0]
    outs = Product[p[1] for p in outputs if p[2]>0]

    # --- internal connections

    internal_connections = Set{Connection}()
    for p in internal_12
        if p[2]>0
            push!(internal_connections, (p[1], tech1, tech2))
        end
    end
    for p in internal_21
        if p[2]>0
            push!(internal_connections, (p[1], tech2, tech1))
        end
    end


    # name and apps score
    name = join(sort([tech1.name, tech2.name]), " :: ")
    appscore = sort(vcat(tech1.appscore, tech2.appscore))

    # make input variations
    newtechs = TechCombined[]
    tech = TechCombined(sort(ins), sort(outs), name, tech1.functional_group,
                        appscore, length(ins),
                        Set([tech1, tech2]), internal_connections)
    push!(newtechs, tech)
    for additional_inputs = Combinatorics.combinations(internal_products)
         ins2 = vcat([ins..., additional_inputs...]...)
        tech = TechCombined(sort(ins2), sort(outs), name, tech1.functional_group,
                             appscore, length(ins),
                             Set([tech1, tech2]), internal_connections)
         push!(newtechs, tech)
    end

    return newtechs
end
