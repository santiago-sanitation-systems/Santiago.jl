using DataFrames
using Iterators
using Combinatorics

export importTechFile
export writedotfile
export generateCombinations

type MasterTech
  name::String
  inputs::Array
  outputs::Array
  functional_group::String
  appscore::Float64
  inrel::String
  outrel::String
  MasterTech() = new()
end

"""
This function reads a .csv file with technology and relationships
and returns a tuple of an array with sources and an array of all technologies
"""
function importTechFile(techFile::String, sourceGroup::String, sourceAddGroup::String, t_group::String)

  techTable = readtable(techFile, separator = ';',   nastrings = [""], header= false)

  # Load the table into suitable Data Structure
  techList = MasterTech[]
  for i in 2:ncol(techTable)

    # Copy some information
    currentTech = MasterTech()
    currentTech.name = techTable[1,i]
    currentTech.functional_group = techTable[2,i]
	currentTech.appscore = parse(Float64, string(techTable[6,i]))
    currentTech.inputs = Array{String, 1}(0)
    currentTech.outputs = Array{String, 1}(0)
    currentTech.inrel = techTable[4,i]
    currentTech.outrel = techTable[5,i]

    # Separate Inputs and outputs.
    tmp = split(techTable[3,i], " ")
    j = 1
    while (j <= length(tmp)) && (tmp[j] != "->")
      tmp[j] = replace(tmp[j], ",", "")
      push!(currentTech.inputs, tmp[j])
      j += 1
    end
    j += 1
    while j <= length(tmp)
      tmp[j] = replace(tmp[j], ",", "")
      push!(currentTech.outputs, tmp[j])
      j += 1
    end

    # Add to Array
    push!(techList, currentTech)
	
  end


  # Now generate subtechs
  subTechList = Tech[]
  for currentTech in techList
    techFile = "techdata_ex_7.csv"
    # Case 1: Copy | Copy
    if (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "NA" || currentTech.outrel == "AND")
      newSubTech = Tech(currentTech.inputs,
      currentTech.outputs, currentTech.name, currentTech.functional_group, currentTech.appscore)
      push!(subTechList, newSubTech)

      # Case 2: Copy | GenVar
    elseif (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "OR")
      c = 1
      for i in 1:length(currentTech.outputs)
        possibleCombis = collect(combinations(currentTech.outputs, i))
        for subTechOut in possibleCombis
          subTechName = join([currentTech.name, c], "_")
          newSubTech = Tech(currentTech.inputs,
          subTechOut, subTechName, currentTech.functional_group, currentTech.appscore)
          push!(subTechList, newSubTech)
          c += 1
        end
      end

      # Case 3: Copy | Gen1
    elseif (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "XOR")
      for i in 1:length(currentTech.outputs)
        subTechOut = currentTech.outputs[i]
        subTechName = join([currentTech.name, i], "_")
        newSubTech = Tech(currentTech.inputs,
        [subTechOut], subTechName, currentTech.functional_group, currentTech.appscore)
        push!(subTechList, newSubTech)
      end
      techFile = "techdata_ex_7.csv"

      # Case 4: GenVar | Hirarch
    elseif currentTech.inrel == "OR" && (currentTech.outrel != "NA" && currentTech.outrel != "AND")

      # Prepare (get the hirarchy)
      hira = split(currentTech.outrel, " > ")
      if length(hira) != length(currentTech.inputs)
        error("Case 4: Lenght of Hirarchy is expected to be the same as number of Input Products")
      end
      c = 1

      # This bit gets the possible combinations of in-products
      for i in 1:length(currentTech.inputs)
        possibleCombis = collect(combinations(currentTech.inputs, i))
        for subTechIn in possibleCombis
          # This bit checks for the most dominant in-product to determine output
          for candidateOut in hira
            if in(candidateOut, subTechIn)

              # This bit generates the SubTech
              subTechName = join([currentTech.name, c], "_")
              subTechOut = join(["transported", candidateOut], "")
              newSubTech = Tech(subTechIn,
              [subTechOut], subTechName, currentTech.functional_group, currentTech.appscore)
              push!(subTechList, newSubTech)

              c += 1
              break
            end
          end
        end
      end

      # Case 5: Gen1 | Select
    elseif currentTech.inrel == "XOR" && (currentTech.outrel != "NA" && currentTech.outrel != "AND")
      for i in 1:length(currentTech.inputs)
        subTechName = join([currentTech.name, i], "_")
        subTechIn = currentTech.inputs[i]
        subTechOut = join(["transported", subTechIn], "")
        newSubTech = Tech([subTechIn],
        [subTechOut], subTechName, currentTech.functional_group, currentTech.appscore)
        push!(subTechList, newSubTech)
      end

      # Case 6: GenVar | Copy
    elseif currentTech.inrel == "OR" && (currentTech.outrel == "AND" || currentTech.outrel == "NA")
      c = 1
      for i in 1:length(currentTech.inputs)
        possibleCombis = collect(combinations(currentTech.inputs, i))
        for subTechIn in possibleCombis
          subTechName = join([currentTech.name, c], "_")
          newSubTech = Tech(subTechIn,
          currentTech.outputs, subTechName, currentTech.functional_group, currentTech.appscore)
          push!(subTechList, newSubTech)
          c += 1
        end
      end

      # Case 7: Gen1 | Copy
    elseif currentTech.inrel == "XOR" && (currentTech.outrel == "AND" || currentTech.outrel == "NA")
      for i in 1:length(currentTech.inputs)
        subTechIn = currentTech.inputs[i]
        subTechName = join([currentTech.name, i], "_")
        newSubTech = Tech([subTechIn],
        currentTech.outputs, subTechName, currentTech.functional_group, currentTech.appscore)
        push!(subTechList, newSubTech)
      end

      # Case 8: Other syntax
    else
      print(currentTech.inrel)
      print(currentTech.outrel)
      error("Case 8: Unrecognized Syntax Inrel.")
    end
  end
  
  # Filter: for Technologies with group t_group it is not allowed that an input "A" and a transported input "transportedA"
  # appear at the same time.
  subTechFiltered = Tech[]
  for subTech in subTechList
	islegal = true
	for input in subTech.inputs
		t_input = join([Symbol("transported"), Symbol(input.name)], "")
		for i in subTech.inputs
			if Symbol(t_input) == i.name && subTech.functional_group == Symbol(t_group)
				islegal = false
			end
		end
	end
	if islegal
		push!(subTechFiltered, subTech)
	end
  end

  sources = filter(t -> t.functional_group == Symbol(sourceGroup), subTechFiltered)
  sourcesAdd = filter(t -> t.functional_group == Symbol(sourceAddGroup), subTechFiltered)
  techs = filter(t -> (t.functional_group != Symbol(sourceGroup) && t.functional_group != Symbol(sourceAddGroup)), subTechFiltered)

  return sources, sourcesAdd, techs

end

"""
This function generates possible combinations of one source and all sourcesAdds
returns all possible combinations.
"""
function generateCombinations(source::Tech, sourcesAdd::Array{Tech})

	src_comb = Array{Tech}[]
	push!(src_comb, [source])
	
	for s_pos in Combinatorics.combinations(sourcesAdd)
		push!(s_pos, source)
		push!(src_comb, s_pos)
	end
	
	return src_comb
end



# ---------------------------------
# write dot file for visualisation with graphviz

"""
Writes a DOT file of a `System`. The resulting file can be visualized with GraphViz, e,g.:
```
 dot -Tpng file.dot -o graph.png
```
## Arguments
nogroup    Array of functional groups which should not be grouped in the plot

"""
function writedotfile(sys::System, file::String, no_group::Array{String}=[""], options::String="")
    open(file, "w") do f
        println(f, "digraph system {")
        println(f, "rankdir=LR;")
        println(f, "node[style=filled colorscheme=pastel15];") # accent5
        if options!=""
            println(f, "$(options);")
        end
        # define colors for function groups
        fgroups = sort(unique(t.functional_group for t in sys.techs))
        colors = Dict(fgroups[i] => mod(i,5)+1 for i in 1:length(fgroups))

        # define nodes
        for t in vcat(sys.techs...)
            println(f, replace("$(t.name) [shape=box, fillcolor=$(colors[t.functional_group]) label=\"$(t.name)\n($(t.functional_group))\"];", ".", "_"))
        end
        # edges
        for c in sys.connections
            println(f, replace("$(c[2].name) -> $(c[3].name) [label=\"$(c[1].name)\"];", ".", "_"))
        end

        no_group = [Symbol(x) for x in no_group]
        # group according to functional groups
        for fg in filter(x -> !(x in no_group), fgroups)
            names = [t.name for t in sys.techs if t.functional_group==fg]
            names = map(n -> replace(n, ".", "_"), names)
            println(f, "{ rank=same $(join(names, ' ')) }")
        end

        println(f, "}")
    end
end
