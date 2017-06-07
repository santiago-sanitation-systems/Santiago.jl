using AutoHashEquals

import DataStructures
import Combinatorics
import Base.show
import Base.getindex
import Base.copy
import Base.==
import StatsBase

export Tech, Product, System
export build_all_systems
export writedotfile
export prefilterTechList

# -----------
# define types


@auto_hash_equals immutable Product
  name::Symbol
end

Product(name::String) = Product(Symbol(name))
==(a::Product, b::Product) = a.name==b.name
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

System(techs::Array{Tech}, con::Array{Connection}, complete::Bool) = System(Set(techs), Set(con), complete)
System(techs::Array{Tech}, con::Array{Connection}) = System(Set(techs), Set(con), false)
System(techs::Array{Tech}) = System(Set(techs), Set(Connection[]), false)

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

function get_outputs{T<:Union{Array{Tech}, Set{Tech}}}(techs::T)
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
    idx = find(outs .== c[1]) # get index of appl products mathing c
    deleteat!(outs, idx[1])   # remove one product
  end
  return outs
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
function get_candidates(s::Array{Tech}, outs, k)

  n_out = length(outs)
  n_in_max = n_out - k + 1

  function condi(t::Tech)
    issubset(t.inputs, outs) && (t.n_inputs <= n_in_max)
  end

  filter(condi, s)
end


# -----------
# functions to find all systems

# Return a vector of Systems
function build_system!(sys::System, completesystems::Array{System}, deadendsystems::Array{System},
  techs::Array{Tech}, islegal::Function, sysappscore::Function, resultfile::IO,
  hashset::Set{UInt64}, storeDeadends::Bool)

  # get Array of matching Techs Arrays
  candidates = get_candidates(sys, techs)

  if storeDeadends && length(candidates) == 0
    push!(deadendsystems, sys)
  end

  for candidate in candidates
    # extend systems
    sys_ext = extend_system(sys, candidate)

    if sys_ext.complete && !(sys_ext in completesystems)
      push!(completesystems, sys_ext)
      println(resultfile, sys_ext)
      println(resultfile, "Sysappscore: $(sysappscore(sys_ext))\n---\n")
      flush(resultfile)
    elseif !sys_ext.complete && islegal(sys_ext) && !(hash(sys_ext) in hashset)
      push!(hashset, hash(sys_ext))
      build_system!(sys_ext, completesystems, deadendsystems,
      techs, islegal, sysappscore, resultfile, hashset, storeDeadends)
    end

  end
end


"""
Returns an Array of all possible `System`s starting with `source`. A source can be any technology with a least one output.
"""
function build_all_systems(source::Array{Tech}, techs::Array{Tech}; islegal::Function=x -> true,
  resultfile::IO=STDOUT, sysappscore::Function=x -> 0, storeDeadends::Bool=false)
  completesystems = System[]
  deadendsystems = System[]
  build_system!(System(source), completesystems, deadendsystems, techs, islegal, sysappscore, resultfile, Set{UInt64}(), storeDeadends)
  return completesystems, deadendsystems
end


# Returns techs that fit to an open system
function get_candidates(sys::System, techs::Array{Tech})

  techssub = filter(t -> !(t in sys.techs), techs) # filter out already used techs
  outs = get_outputs(sys)

  matching_techs = Array{Array{Tech},1}()
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

  return matching_techs
end


# test if outputs are compatible with next inputs.
function is_compatible(outputs, inputs)
  outputs = DataStructures.counter(outputs)
  inputs = DataStructures.counter(inputs)

  # exclude spliting of one output to multiple inputs
  for prod in keys(outputs)
     if outputs[prod] < inputs[prod] return false
  end
  return true
end


"""
Return an array of all possible extension of `sys` with the candidate technology
"""
function extend_system(sys::System, tech_comb::Array{Tech})
  sysi = copy(sys)
  # --- add new techologies
  union!(sysi.techs, tech_comb)

  for tech in tech_comb
    for prodin in tech.inputs

      # --- connection to new tech
      last_tech = collect(get_openout_techs(sys, prodin))  # get a technology with output = "prodin" BUG!

      push!(sysi.connections, (prodin, last_tech[1], tech)) # add new connection
    end
  end

  sysi.complete = is_complete(sysi)

  return sysi
end

"""
Return an array possible Technologies (subset of techlist) for the given Sources.
The number of technologies is reduced by removing Techs that require an input that is not available with
the sources provided.
"""
function prefilterTechList(currentSources::Array{Tech}, sources::Array{Tech},
  sourcesAdd::Array{Tech}, tech_list::Array{Tech})

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
  push!(otherSourcesProduct, "^[.]") # this is a dummy patter to ensure that ffilter works if otherSourcesProduct is empty


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
