using Combinatorics
export importTechFile
export writedotfile
export generateCombinations

mutable struct MasterTech
    name::String
    inputs::Array
    outputs::Array
    functional_group::String
    appscore::Float64
    inrel::String
    outrel::String
    transC
    transC_reliability
    MasterTech() = new()
end

"""
This function reads a .csv file with technology and relationships
and returns a tuple of an array with sources and an array of all technologies
"""
function importTechFile(techFile::String; sourceGroup::String="U",
                        sourceAddGroup::String="Uadd", sinkGroup::String="D")

    techTable = readdlm(techFile, ';')

    ## Load the table into suitable Data Structure
    techList = MasterTech[]
    for i in 2:size(techTable,2)

        ## Copy some information
        currentTech = MasterTech()
        currentTech.name = techTable[1,i]
        currentTech.functional_group = techTable[2,i]
        currentTech.appscore = parse(Float64, string(techTable[6,i]))
        currentTech.inputs = Array{String, 1}(0)
        currentTech.outputs = Array{String, 1}(0)
        currentTech.inrel = techTable[4,i]
        currentTech.outrel = techTable[5,i]

        ## Separate Inputs and outputs.
        tmp = split(techTable[3,i], " ")
        filter!(x -> x != "", tmp)
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

        ## read transfer coefficients

        function make_transC_substance_dict(s::String)
            d = Dict{Product, Float64}()
            tmp = [split(replace(x, " ", ""), '=') for x in split(s, ',')]
            for t in tmp
                d[Product(t[1])] = parse(Float64, t[2])
            end
            return d
        end

        transC = Dict{String, Dict{Product, Float64}}()
        transC_rel = Dict{String, Float64}()
        for k in 1:NSUBSTANCE
            transC[SUBSTANCE_NAMES[k]] = make_transC_substance_dict(String(techTable[5+2*k,i]))
            transC_rel[SUBSTANCE_NAMES[k]] = convert(Float64, techTable[6+2*k,i])
        end
        currentTech.transC = transC
        currentTech.transC_reliability = transC_rel


        for sub in SUBSTANCE_NAMES
            if '>' in currentTech.outrel   # is transport technolgy
                needed_keys = Set([Product("x"), Product("airloss"), Product("soilloss"), Product("waterloss")])
            else
                if length(currentTech.outputs) > 0 # is not sink
                    out_tmp = [replace(p, "transported", "") for p in currentTech.outputs]
                    needed_keys = Set(vcat(Product.(out_tmp), [Product("airloss"), Product("soilloss"), Product("waterloss")]))
                else                # is sink
                    needed_keys = Set([Product("recovered"), Product("airloss"), Product("soilloss"), Product("waterloss")])
                end
            end
            if needed_keys != Set(keys(currentTech.transC[sub]))
                diff_element = setdiff(needed_keys, Set(keys(currentTech.transC[sub])))
                error("Transfere coefficients for Tech $(techTable[1,i]) (column $i) do not match for $sub.
  No match for: $([String(e.name) for e in diff_element])")
            end
        end

        ## Add to Array
        push!(techList, currentTech)

    end


    ## help function to generate two Techs with only "transported" or "not transported" output products
    function make2(t::Tech)

        if t.functional_group != Symbol(sinkGroup)      # of t is not a sink
            outs = t.outputs
            out_transported = filter(p -> contains(string(p.name), "transported"), outs)
            out_NOTtransported = filter(p -> !contains(string(p.name), "transported"), outs)

            ## produce array of two Techs
            techs = Tech[Tech(t.inputs,
                              out_NOTtransported,
                              t.name,
                              t.functional_group,
                              t.appscore,
                              t.n_inputs,
                              t.transC,
                              t.transC_reliability),
                         Tech(t.inputs,
                              out_transported,
                              t.name*"_trans",
                              t.functional_group,
                              t.appscore,
                              t.n_inputs,
                              t.transC,
                              t.transC_reliability)]

            return filter!(t -> length(t.outputs)>0, techs)
        else                    # if sink just return it as is
            [t]
        end
    end

    ## Now generate subtechs
    subTechList = AbstractTech[]
    for currentTech in techList
        ## Case 1: Copy | Copy
        if (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "NA" || currentTech.outrel == "AND")

            newSubTech = Tech(currentTech.inputs,
                              currentTech.outputs,
                              currentTech.name,
                              currentTech.functional_group,
                              currentTech.appscore,
                              currentTech.transC,
                              currentTech.transC_reliability)

            append!(subTechList, make2(newSubTech))


            ## Case 2: Copy | GenVar
        elseif (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "OR")
            error(" The relationship of output products cannot be defined as 'OR'!")

            ## Case 3: Copy | Gen1
        elseif (currentTech.inrel == "NA" || currentTech.inrel == "AND") && (currentTech.outrel == "XOR")
            error(" The relationship of output products cannot be defined as 'XOR'!")

            ## Case 4: GenVar | Hierarchy
        elseif currentTech.inrel == "OR" && (currentTech.outrel != "NA" && currentTech.outrel != "AND")

            ## Prepare (get the hierarchy)
            hira = split(currentTech.outrel, " > ")
            if length(hira) != length(currentTech.inputs)
                error("Case 4: Lenght of Hierarchy is expected to be the same as number of Input Products")
            end
            c = 1

            ## This bit gets the possible combinations of in-products
            for i in 1:length(currentTech.inputs)
                possibleCombis = collect(combinations(currentTech.inputs, i))
                for subTechIn in possibleCombis
                    ## This bit checks for the most dominant in-product to determine output
                    for candidateOut in hira
                        if in(candidateOut, subTechIn)

                            ## This bit generates the SubTech
                            subTechName = join([currentTech.name, c], "_")
                            subTechOut = join(["transported", candidateOut], "")
                            newSubTech = Tech(subTechIn,
                                              [subTechOut],
                                              subTechName,
                                              currentTech.functional_group,
                                              currentTech.appscore,
                                              currentTech.transC,
                                              currentTech.transC_reliability)
                            push!(subTechList, newSubTech)

                            c += 1
                            break
                        end
                    end
                end
            end

            ## Case 5: Gen1 | Select
        elseif currentTech.inrel == "XOR" && (currentTech.outrel != "NA" && currentTech.outrel != "AND")
            for i in 1:length(currentTech.inputs)
                subTechName = join([currentTech.name, i], "_")
                subTechIn = currentTech.inputs[i]
                subTechOut = join(["transported", subTechIn], "")
                newSubTech = Tech([subTechIn],
                                  [subTechOut],
                                  subTechName,
                                  currentTech.functional_group,
                                  currentTech.appscore,
                                  currentTech.transC,
                                  currentTech.transC_reliability)
                push!(subTechList, newSubTech)
            end

            ## Case 6: GenVar | Copy
        elseif currentTech.inrel == "OR" && (currentTech.outrel == "AND" || currentTech.outrel == "NA")
            c = 1
            for i in 1:length(currentTech.inputs)
                possibleCombis = collect(combinations(currentTech.inputs, i))
                for subTechIn in possibleCombis
                    subTechName = join([currentTech.name, c], "_")
                    newSubTech = Tech(subTechIn,
                                      currentTech.outputs,
                                      subTechName,
                                      currentTech.functional_group,
                                      currentTech.appscore,
                                      currentTech.transC,
                                      currentTech.transC_reliability)
                    append!(subTechList, make2(newSubTech))
                    c += 1
                end
            end

            ## Case 7: Gen1 | Copy
        elseif currentTech.inrel == "XOR" && (currentTech.outrel == "AND" || currentTech.outrel == "NA")
            for i in 1:length(currentTech.inputs)
                subTechIn = currentTech.inputs[i]
                subTechName = join([currentTech.name, i], "_")
                newSubTech = Tech([subTechIn],
                                  currentTech.outputs,
                                  subTechName,
                                  currentTech.functional_group,
                                  currentTech.appscore,
                                  currentTech.transC,
                                  currentTech.transC_reliability)
                append!(subTechList, make2(newSubTech))
            end

## Case 8: Other syntax
else
print(currentTech.inrel)
print(currentTech.outrel)
error("Case 8: Unrecognized Syntax Inrel.")
end
end

## Filter: for all Techs that are not in c_group:
##         either ALL inputs and outputs are "transported" or ALL inputs and outputs are "NOT transported".
function islegal(t::Tech)
    inp  = [string(s.name) for s in t.inputs]
    outp = [string(s.name) for s in t.outputs]

    inp_trans  = [contains(i, "transported") for i in inp]
    outp_trans = [contains(i, "transported") for i in outp]

    ##        is transport              |         everything is transported  | nothing is transported
    (t.functional_group == Symbol("C")) | (all(inp_trans) & all(outp_trans)) | (all(.!(inp_trans)) & all(.!(outp_trans)))
end


subTechFiltered = filter(islegal, subTechList)


# Test if all technologies in the input file exist at least in one form in the final tech lists
for t in techList
    if !any(contains(x.name, t.name) for x in subTechFiltered)
        error("Tech '$(t.name)' is not imported! Check csv file carefully!")
    end
end

## separate sources, sourcesAdd, and Technologies
sources = filter(t -> t.functional_group == Symbol(sourceGroup), subTechFiltered)
sourcesAdd = filter(t -> t.functional_group == Symbol(sourceAddGroup), subTechFiltered)
techs = filter(t -> (t.functional_group != Symbol(sourceGroup) && t.functional_group != Symbol(sourceAddGroup)), subTechFiltered)


return sources, sourcesAdd, techs

end

"""
     This function generates possible combinations of one source and all sourcesAdds
     returns all possible combinations.
    """
function generateCombinations{T <: AbstractTech}(source::T, sourcesAdd::Array{T})

    src_comb = Array{Tech}[]
    push!(src_comb, [source])

    for s_pos in Combinatorics.combinations(sourcesAdd)
        push!(s_pos, source)
        push!(src_comb, s_pos)
    end

    return src_comb
end



## ---------------------------------
## write dot file for visualisation with graphviz

"""
 Writes a DOT file of a `System`. The resulting file can be visualized with GraphViz, e,g.:
 ```
 dot -Tpng file.dot -o graph.png
 ```
 ## Arguments
 nogroup    Array of functional groups which should not be grouped in the plot

 """
function writedotfile(sys::System, file::String, no_group::Array{String}=["S", "C", "T"], options::String="")
    make_legal(name::String) = replace(name, " :: ", "")

    open(file, "w") do f
        println(f, "digraph system {")
        println(f, "rankdir=LR;")
        println(f, "node[style=filled colorscheme=pastel15];") # accent5
        if options!=""
            println(f, "$(options);")
        end

        if haskey(sys.properties, "ID")
            println(f, "label=\"ID: $(sys.properties["ID"])\";")
            println(f, "labelfontsize=22.0;")
            println(f, "labelloc=\"top\";")
            println(f, "labeljust=left")
        end

        ## define colors for function groups
        fgroups = sort(unique(t.functional_group for t in sys.techs))
        colors = Dict(fgroups[i] => mod(i,5)+1 for i in 1:length(fgroups))

        colors = Dict(:U => "# F15A31", :S => "# F99D34", :C => "# C1C430", :T => "# 70BF54", :D => "# 00B6CD")


        ## define nodes
        for t in vcat(sys.techs...)
            label = "$(t.name)\n"
            label = label * "($(t.functional_group))"
            println(f, replace("$(make_legal(t.name)) [shape=box, fillcolor=\"$(get(colors, t.functional_group, "# 999999"))\" label=\"$label\"];", ".", "_"))
        end
        ## edges
        for c in sys.connections
            println(f, replace("$(make_legal(c[2].name)) -> $(make_legal(c[3].name)) [label=\"$(c[1].name)\"];", ".", "_"))
        end

        no_group = [Symbol(x) for x in no_group]
        ## group according to functional groups
        for fg in filter(x -> !(x in no_group), fgroups)
            names = [t.name for t in sys.techs if t.functional_group==fg]
            names = map(n -> make_legal(replace(n, ".", "_")), names)
            println(f, "{ rank=same $(join(names, ' ')) }")
        end

        println(f, "}")
    end
end
