using Combinatorics
import JSON3

export import_technologies
    export writedotfile

# ---------------------------------
# import of tech files

# helpers to read out the dictionaries of the TC correctly
function TC_dict(jsontech::JSON3.Object)
    dTC = Dict{String, Dict{Product, Float64}}()
    for p in SanitationSystemMassFlow.SUBSTANCE_NAMES
        dTC[p] = Dict{Product, Float64}()
        for (k,v) in jsontech.massflow[Symbol(p)].TC
            dTC[p][Product(k)] = v
        end
    end
    dTC
end

function TCr_dict(jsontech::JSON3.Object)
    dTC_r = Dict{String, Float64}()
    for p in SanitationSystemMassFlow.SUBSTANCE_NAMES
        dTC_r[p] = jsontech.massflow[Symbol(p)].k
    end
    dTC_r
end

## helper function to generate two Techs with only "transported" or "not transported" output products
function make2(t::Tech, sinkGroup)

    if t.functional_group != Symbol(sinkGroup)      # if t is not a sink
        outs = t.outputs
        out_transported = filter(p -> occursin("transported", string(p.name)), outs)
        out_NOTtransported = filter(p -> !occursin("transported", string(p.name)), outs)

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


"""
This function reads a `json` file defing the technologies
and returns i) array with sources, ii) array with additional sources,
 and iii) an array of all technologies.
"""
function import_technologies(techFile::String; sourceGroup::String="U",
                             sourceAddGroup::String="Uadd", sinkGroup::String="D")

    ## Read json file
    rawtechs = open(techFile,"r") do f
        JSON3.read(f)
    end

    ## Generate subtechs
    subTechList = AbstractTech[]

    for i in 1:length(rawtechs)
        rtech = rawtechs[i]     # tech in JSON format


        ## Case 1: Copy | Copy
        if (rtech.inputs.relationship == "NA" || rtech.inputs.relationship == "AND") && (rtech.outputs.relationship == "NA" || rtech.outputs.relationship == "AND")

            newSubTech = Tech(length(rtech.inputs.product)>0 ? Product.(rtech.inputs.product) : Product[],
                              length(rtech.outputs.product)>0 ? Product.(rtech.outputs.product) : Product[],
                              rtech.name,
                              Symbol(rtech.functionalgroup),
                              [rtech.appscore],
                              length(rtech.inputs.product),
                              TC_dict(rtech),
                              TCr_dict(rtech))
            append!(subTechList, make2(newSubTech, sinkGroup))

            ## Case 2: Copy | GenVar
        elseif (rtech.inputs.relationship == "NA" || rtech.inputs.relationship == "AND") && (rtech.outputs.relationship == "OR")
            error(" The relationship of output products cannot be defined as 'OR'!")

            ## Case 3: Copy | Gen1
        elseif (rtech.inputs.relationship == "NA" || rtech.inputs.relationship == "AND") && (rtech.outputs.relationship == "XOR")
            error(" The relationship of output products cannot be defined as 'XOR'!")

            ## Case 4: GenVar | Hierarchy
        elseif rtech.inputs.relationship == "OR" && (rtech.outputs.relationship != "NA" && rtech.outputs.relationship != "AND")

            ## Prepare (get the hierarchy)
            hira = split(rtech.outputs.relationship, " > ")
            if length(hira) != length(rtech.inputs.product)
                error("Case 4: Lenght of Hierarchy is expected to be the same as number of Input Products")
            end
            c = 1

            ## This bit gets the possible combinations of in-products
            for i in 1:length(rtech.inputs.product)
                possibleCombis = collect(combinations(rtech.inputs.product, i))
                for subTechIn in possibleCombis
                    ## This bit checks for the most dominant in-product to determine output
                    for candidateOut in hira
                        if in(candidateOut, subTechIn)

                            ## This bit generates the SubTech
                            subTechName = join([rtech.name, c], "_")
                            subTechOut = join(["transported", candidateOut], "")
                            newSubTech = Tech(Product.(subTechIn),
                                              Product.([subTechOut]),
                                              subTechName,
                                              Symbol(rtech.functionalgroup),
                                              [rtech.appscore],
                                              length(subTechIn),
                                              TC_dict(rtech),
                                              TCr_dict(rtech))

                            push!(subTechList, newSubTech)

                            c += 1
                            break
                        end
                    end
                end
            end

            ## Case 5: Gen1 | Select
        elseif rtech.inputs.relationship == "XOR" && (rtech.outputs.relationship != "NA" && rtech.outputs.relationship != "AND")
            for i in 1:length(rtech.inputs.product)
                subTechName = join([rtech.name, i], "_")
                subTechIn = rtech.inputs.product[i]
                subTechOut = join(["transported", subTechIn], "")
                newSubTech = Tech(Product.([subTechIn]),
                                  Product.([subTechOut]),
                                  subTechName,
                                  Symbol(rtech.functionalgroup),
                                  [rtech.appscore],
                                  length(subTechIn),
                                  TC_dict(rtech),
                                  TCr_dict(rtech))
                push!(subTechList, newSubTech)
            end

            ## Case 6: GenVar | Copy
        elseif rtech.inputs.relationship == "OR" && (rtech.outputs.relationship == "AND" || rtech.outputs.relationship == "NA")
            c = 1
            for i in 1:length(rtech.inputs.product)
                possibleCombis = collect(combinations(rtech.inputs.product, i))
                for subTechIn in possibleCombis
                    subTechName = join([rtech.name, c], "_")
                    newSubTech = Tech(Product.(subTechIn),
                                      length(rtech.outputs.product)>0 ? Product.(rtech.outputs.product) : Product[],
                                      subTechName,
                                      Symbol(rtech.functionalgroup),
                                      [rtech.appscore],
                                      length(subTechIn),
                                      TC_dict(rtech),
                                      TCr_dict(rtech))
                    append!(subTechList, make2(newSubTech, sinkGroup))
                    c += 1
                end
            end

            ## Case 7: Gen1 | Copy
        elseif rtech.inputs.relationship == "XOR" && (rtech.outputs.relationship == "AND" || rtech.outputs.relationship == "NA")
            for i in 1:length(rtech.inputs.product)
                subTechIn = rtech.inputs.product[i]
                subTechName = join([rtech.name, i], "_")
                newSubTech = Tech(Product.([subTechIn]),
                                  length(rtech.outputs.product)>0 ? Product.(rtech.outputs.product) : Product[],
                                  subTechName,
                                  Symbol(rtech.functionalgroup),
                                  [rtech.appscore],
                                  length(subTechIn),
                                  TC_dict(rtech),
                                  TCr_dict(rtech))
                append!(subTechList, make2(newSubTech, sinkGroup))
            end

            ## Case 8: Other syntax
        else
            error("Case 8: Unrecognized Syntax Inrel.")
        end
    end

    ## Filter: for all Techs that are not in c_group:
    ##         either ALL inputs and outputs are "transported" or ALL inputs and outputs are "NOT transported".
    function islegal(t::Tech)
        inp  = [string(s.name) for s in t.inputs]
        outp = [string(s.name) for s in t.outputs]

        inp_trans  = [occursin("transported", i) for i in inp]
        outp_trans = [occursin("transported", i) for i in outp]

        ##        is transport              |         everything is transported  | nothing is transported
        (t.functional_group == Symbol("C")) | (all(inp_trans) & all(outp_trans)) | (all(.!(inp_trans)) & all(.!(outp_trans)))
    end


    subTechFiltered = filter(islegal, subTechList)


    # Test if all technologies in the input file exist at least in one form in the final tech lists
    for t in rawtechs
        if !any(occursin(t.name, x.name) for x in subTechFiltered)
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
function generateCombinations(source::T, sourcesAdd::Array{T}) where T <: AbstractTech

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

    make_legal(name::String) = replace(name, " :: " => "")

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
            println(f, replace("$(make_legal(t.name)) [shape=box, fillcolor=\"$(get(colors, t.functional_group, "# 999999"))\" label=\"$label\"];", "." => "_"))
                               end
                               ## edges
                               for c in sys.connections
                               println(f, replace("$(make_legal(c[2].name)) -> $(make_legal(c[3].name)) [label=\"$(c[1].name)\"];", "." => "_"))
                               end

                               no_group = [Symbol(x) for x in no_group]
                               ## group according to functional groups
                               for fg in filter(x -> !(x in no_group), fgroups)
            names = [t.name for t in sys.techs if t.functional_group==fg]
                               names = map(n -> make_legal(replace(n, "." => "_")), names)
                               println(f, "{ rank=same $(join(names, ' ')) }")
        end

        println(f, "}")
    end
end
