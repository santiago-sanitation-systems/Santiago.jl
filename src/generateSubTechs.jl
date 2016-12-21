using DataFrames
using Iterators
using Combinatorics

type MasterTech
  name::String
  inputs::Array
  outputs::Array
  functional_group::String
  inrel::String
  outrel::String
  MasterTech() = new()
end

type Tech
  name::String
  inputs::Array
  outputs::Array
  functional_group::String
end

function generateSubTechs(techFile::String)

techTable = readtable(techFile, separator = ';',   nastrings = [""], header= false)

# Load the table into suitable Data Structure
techList = MasterTech[]
for i in 2:ncol(techTable)

  # Copy some information
  currentTech = MasterTech()
  currentTech.name = techTable[1,i]
  currentTech.functional_group = techTable[2,i]
  currentTech.inputs = Array{String, 1}(0)
  currentTech.outputs = Array{String, 1}(0)
  currentTech.inrel = techTable[4,i]
  currentTech.outrel = techTable[5,i]

  # Separate Inputs and outputs.
  tmp = split(techTable[3,i], " ")
  j = 1
  while tmp[j] != "->"
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
    newSubTech = Tech(currentTech.name, currentTech.inputs,
      currentTech.outputs, currentTech.functional_group)
    push!(subTechList, newSubTech)

  # Case 2: Copy | GenVar
  elseif (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "OR")
    c = 1
    for i in 1:length(currentTech.outputs)
      possibleCombis = collect(combinations(currentTech.outputs, i))
      for subTechOut in possibleCombis
        subTechName = join([currentTech.name, c], "_")
        newSubTech = Tech(subTechName, currentTech.inputs,
          subTechOut, currentTech.functional_group)
        push!(subTechList, newSubTech)
        c += 1
      end
    end

  # Case 3: Copy | Gen1
  elseif (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "XOR")
    for i in 1:length(currentTech.outputs)
      subTechOut = currentTech.outputs[i]
      subTechName = join([currentTech.name, i], "_")
      newSubTech = Tech(subTechName, currentTech.inputs,
        [subTechOut], currentTech.functional_group)
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
            newSubTech = Tech(subTechName, subTechIn,
              [subTechOut], currentTech.functional_group)
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
      newSubTech = Tech(subTechName, [subTechIn],
        [subTechOut], currentTech.functional_group)
      push!(subTechList, newSubTech)
    end

  # Case 6: GenVar | Copy
  elseif currentTech.inrel == "OR" && (currentTech.outrel == "AND" || currentTech.outrel == "NA")
    c = 1
    for i in 1:length(currentTech.inputs)
      possibleCombis = collect(combinations(currentTech.inputs, i))
      for subTechIn in possibleCombis
        subTechName = join([currentTech.name, c], "_")
        newSubTech = Tech(subTechName, subTechIn,
          currentTech.outputs, currentTech.functional_group)
        push!(subTechList, newSubTech)
        c += 1
      end
    end

  # Case 7: Gen1 | Copy
  elseif currentTech.inrel == "XOR" && (currentTech.outrel == "AND" || currentTech.outrel == "NA")
    for i in 1:length(currentTech.inputs)
      subTechIn = currentTech.inputs[i]
      subTechName = join([currentTech.name, i], "_")
      newSubTech = Tech(subTechName, [subTechIn],
        currentTech.outputs, currentTech.functional_group)
      push!(subTechList, newSubTech)
    end

  # Case 8: Other syntax
  else
    print(currentTech.inrel)
    print(currentTech.outrel)
    error("Case 8: Unrecognized Syntax Inrel.")
  end
end

# Print it outptechFile = "techdata_ex_7.csv"
while length(subTechList) > 0
  currentPrint = pop!(subTechList)
  inprods = join(currentPrint.inputs, ", ")
  outprods = join(currentPrint.outputs, ", ")
  products = join([inprods, outprods], "  →→  ")
  printtext = join([currentPrint.name, products], ": ")
  printline = join([printtext, "\n"], "")
  print(printline)
end

end

# Test Function
techFile = "techdata_ex_7.csv"
generateSubTechs(techFile)
