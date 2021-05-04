using Reexport: @reexport
@reexport using JSON3

using Combinatorics: combinations
import StructTypes
using DataFrames


export import_technologies, properties_dataframe
export dot_file, dot_string


# remove number and 'trans' from name
simplifytechname(name) = replace(name, r"(_[0-9]*)?(_trans)?$" => "")


# ---------------------------------
# import of tech files

# helpers to read out the dictionaries of the TC correctly
function TC_dict(jsontech::JSON3.Object)
    dTC = Dict{String, Dict{Product, Float64}}()
    for p in Santiago.SUBSTANCE_NAMES
        dTC[p] = Dict{Product, Float64}()
        for (k,v) in jsontech.massflow[Symbol(p)].TC
            dTC[p][Product(k)] = v
        end
    end
    dTC
end

function TCr_dict(jsontech::JSON3.Object)
    dTC_r = Dict{String, Float64}()
    for p in Santiago.SUBSTANCE_NAMES
        dTC_r[p] = jsontech.massflow[Symbol(p)].k
    end
    dTC_r
end

# helper function to generate two Techs with only "transported" or "not transported" output products
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
```
import_technologies(techFile::String; sourceGroup::String="U",
                    sourceAddGroup::String="Uadd", sinkGroup::String="D")
```

Reads a `json` file defing the technologies
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
                              [-1.0],
                              length(rtech.inputs.product),
                              TC_dict(rtech),
                              TCr_dict(rtech))
            append!(subTechList, make2(newSubTech, sinkGroup))

            ## Case 2: Copy | GenVar
        elseif (rtech.inputs.relationship == "NA" || rtech.inputs.relationship == "AND") && (rtech.outputs.relationship == "OR")
            error("Tech '$(rtech.name)': The relationship of output products cannot be defined as 'OR'!")

            ## Case 3: Copy | Gen1
        elseif (rtech.inputs.relationship == "NA" || rtech.inputs.relationship == "AND") && (rtech.outputs.relationship == "XOR")
            error("Tech '$(rtech.name)': The relationship of output products cannot be defined as 'XOR'!")

            ## Case 4: GenVar | Hierarchy
        elseif rtech.inputs.relationship == "OR" && (rtech.outputs.relationship != "NA" && rtech.outputs.relationship != "AND")

            ## Prepare (get the hierarchy)
            hira = split(rtech.outputs.relationship, " > ")
            if length(hira) != length(rtech.inputs.product)
                error("Tech '$(rtech.name)' (case 4): Length of hierarchy is expected to be the same as number of Input Products")
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
                                              [-1.0],
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
                newSubTech = Tech([Product(subTechIn)],
                                  Product.([subTechOut]),
                                  subTechName,
                                  Symbol(rtech.functionalgroup),
                                  [-1.0],
                                  1,
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
                                      [-1.0],
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
                newSubTech = Tech([Product(subTechIn)],
                                  length(rtech.outputs.product)>0 ? Product.(rtech.outputs.product) : Product[],
                                  subTechName,
                                  Symbol(rtech.functionalgroup),
                                  [-1.0],
                                  1,
                                  TC_dict(rtech),
                                  TCr_dict(rtech))
                append!(subTechList, make2(newSubTech, sinkGroup))
            end

            ## Case 8: Other syntax
        else
            error("Tech '$(rtech.name)' (case 8): Unrecognized input/output relationship.")
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
    n_nonimport = 0
    for t in rawtechs
        if !any(occursin(t.name, x.name) for x in subTechFiltered)
            @warn "Tech '$(t.name)' is not imported! Check definition in technology file carefully!"
            n_nonimport +=1
        end
    end

    ## separate sources, sourcesAdd, and Technologies
    sources = filter(t -> t.functional_group == Symbol(sourceGroup), subTechFiltered)
    sourcesAdd = filter(t -> t.functional_group == Symbol(sourceAddGroup), subTechFiltered)
    techs = filter(t -> (t.functional_group != Symbol(sourceGroup) && t.functional_group != Symbol(sourceAddGroup)), subTechFiltered)

    @info "sources imported:\t\t $(lpad(length(sources), 4))"
    @info "additional sources imported:\t $(lpad(length(sourcesAdd), 4))"
    @info "technologies imported:\t\t $(lpad(length(rawtechs)-n_nonimport, 4))"
    n_derived_techs = length(sources) + length(sourcesAdd) + length(techs) - length(rawtechs) - n_nonimport
    @info "additional derived technologies: $(lpad((n_derived_techs), 4))"

    return sources, sourcesAdd, techs

end


"""
```
import_technologies(techFile::String, case_file::String;
                    sourceGroup::String="U", sourceAddGroup::String="Uadd",
                    sinkGroup::String="D")
```


Import a `json` file defining the technologies *and* a
file defining the case. The latter is used to compute the appropriateness scores.

It returns i) array with sources, ii) array
with additional sources, and iii) an array of all technologies with TAS scores.
"""
function import_technologies(tech_file::String, case_file::String;
                             sourceGroup::String="U", sourceAddGroup::String="Uadd",
                             sinkGroup::String="D")


    sources, additional_sources, techs = import_technologies(tech_file)
    tas, _ = appropriateness(tech_file, case_file)
    update_appropriateness!(sources, tas)
    update_appropriateness!(additional_sources, tas)
    update_appropriateness!(techs, tas)

    sources, additional_sources, techs

end


## ---------------------------------
## JSON export

# helper to convert a NamedArray into a nested Dict. Needed for JSON export
function Dict(na::NamedArray)
    ndim = length(size(na))
    if ndim == 1
        return Dict(names(na)[1][i] => na[i] for i in 1:length(na))
    else
        d = Dict()
        for i in 1:size(na, 1)
            idx = [i; fill(:, ndim-1)]
            d[names(na)[1][i]] = Dict(na[idx...])
        end
        return d
    end
end


StructTypes.StructType(::Type{Product}) = StructTypes.StringType()

# Techs
StructTypes.StructType(::Type{Tech}) = StructTypes.Struct()
StructTypes.excludes(::Type{Tech}) = (:n_inputs,)
StructTypes.names(::Type{Tech}) = ((:transC, :TC), # rename some fields for export
                                   (:transC_reliability, :k),)

# define a type to format the JSON export of Systems
struct SystemJSON
    technologies::Array{String} # only names
    properties::Dict
    graphizdot::String
end

function SystemJSON(sys::System)
    # convert NamedArray's of massflow_stats
    p = copy(sys.properties)
    if haskey(p, "massflow_stats")
        p["massflow_stats"] = Dict(k => Dict(v) for (k,v) in p["massflow_stats"])
        if haskey(p["massflow_stats"], "tech_flows")
            p["massflow_stats"]["tech_flows"] = Dict(k => Dict(v) for (k,v) in p["massflow_stats"]["tech_flows"])
        end
    end
    SystemJSON(
        [simplifytechname(t.name) for t in sys.techs],
        p,
        dot_string(sys)
    )
end

StructTypes.StructType(::Type{SystemJSON}) = StructTypes.Struct()

JSON3.write(sys::System) = JSON3.write(SystemJSON(sys))
JSON3.write(io::IO, sys::T; kw...) where T <: System = JSON3.write(io, SystemJSON(sys); kw...)

JSON3.write(sys::Array{System}) = JSON3.write([SystemJSON(s) for s in sys])
JSON3.write(io::IO, sys::Array{T}; kw...) where T <: System = JSON3.write(io, [SystemJSON(s) for s in sys]; kw...)



## ---------------------------------
## export system properties to DataFrame

# helper to export all massflow statistics
function all_massflow_selection(sys::System)
    ms_string = String[]
    for (k, v) in sys.properties["massflow_stats"]
        if k != "tech_flows"
            na = names(v)           # names of NamedArray
            # construct string
            d = reshape(collect(k * " | " * join(n, " | ") for n in Iterators.product(na...)), 1, :)

            append!(ms_string, d)
        end
    end
    ms_string
end

"""
    $TYPEDSIGNATURES

Extract systems properties into a `DataFrame`.

With the argument `massflow_selection` we can select which information should be extracted from the massflow calulation.

Note, massflows per technology ('tech_flows') cannot be export to a Dataframe! Try the JSON export.

### Example:
`massflow_selection = ["recovered | water | mean", "lost | water| air loss | q_0.5"]`
This will extract the mean value of the recovered water and the 50% quantile of the
water lost to air. Note, the order of the values must match the dimensions of the
 `NamedArray` stored in the system propertes!

`massflow_selection` can be set to `"all"` extrace all massflow quantities (which are a lot!).
"""
function properties_dataframe(systems::Array{System}; massflow_selection="all")

    if length(massflow_selection)>0 && ("massflow_stats" ∉ keys(systems[1].properties))
        error("The systems have no mass flow information. \n Either run `massflow_summary!` first or do not export massflow statistics with:\n  `properties_dataframe(system, massflow_selection=[])`.")
    end
    if massflow_selection == "tech_flows" || massflow_selection == ["tech_flows"]
        error("'tech_flows' cannot be exported to a Dataframe. You may want to try the JSON export.")
    end

    # if default, export all stats
    if massflow_selection == "all"
        massflow_selection = all_massflow_selection(systems[1])
    end

    # all properties except 'massflow_stats'
    cnames = Symbol.(keys(systems[1].properties))
    ctypes = typeof.(values(systems[1].properties))
    no_massflow_idx = cnames .!= :massflow_stats
    ctypes = ctypes[no_massflow_idx]
    cnames = cnames[no_massflow_idx]

    # massflow properties
    massflow_selection = replace.(massflow_selection, r"[ ]*\|[ ]*" => "|") # clean spaces
    ssplit = split.(massflow_selection, "|")  # split massflow_selection

    cnames = Symbol.([cnames; replace.(massflow_selection, "|" => "_")])
    ctypes = [ctypes; fill(Float64, length(massflow_selection))]


    d = DataFrame([cnames[i] => ctypes[i][] for i in 1:length(cnames)])

    for sys in systems
        newrow = collect(values(sys.properties))[no_massflow_idx]
        for sel in ssplit
            namarr = sys.properties["massflow_stats"][sel[1]]   # select NamedArray
            if sel[1] != "entered"
                push!(newrow, namarr[String.(sel[2:end])...]) # select value
            else
                push!(newrow, namarr[String.(sel[2]), "entered"])
            end
        end
        push!(d, newrow)
    end

    select!(d, :ID, :)          # make ID first column
    d
end


## ---------------------------------
## write dot file for visualisation with graphviz


function dot_format(sys::System, io::IO, no_group::Array{String}=["S", "C", "T"], options::String="")

    make_legal(name::String) = replace(name, " :: " => "")


    println(io, "digraph system {")
    println(io, "rankdir=LR;")
    println(io, "node[style=filled colorscheme=pastel15];") # accent5
    if options!=""
        println(io, "$(options);")
    end

    if haskey(sys.properties, "ID")
        println(io, "label=\"ID: $(sys.properties["ID"])\";")
        println(io, "labelfontsize=22.0;")
        println(io, "labelloc=\"top\";")
        println(io, "labeljust=left")
    end

    ## define colors for function groups
    fgroups = sort(unique(t.functional_group for t in sys.techs))
    colors = Dict(fgroups[i] => mod(i,5)+1 for i in 1:length(fgroups))

    colors = Dict(:U => "# F15A31", :S => "# F99D34", :C => "# C1C430", :T => "# 70BF54", :D => "# 00B6CD")


    ## define nodes
    for t in vcat(sys.techs...)
        label = "$(simplifytechname(t.name))\n"
        label = label * "($(t.functional_group))"
        col = get(colors, t.functional_group, "# 999999")
        println(io, replace("$(make_legal(t.name)) [shape=box, fillcolor=\"$(col)\" label=\"$label\"];", "." => "_"))
    end
    ## edges
    for c in sys.connections
        println(io, replace("$(make_legal(c[2].name)) -> $(make_legal(c[3].name)) [label=\"$(c[1].name)\"];", "." => "_"))
    end

    no_group = [Symbol(x) for x in no_group]
    ## group according to functional groups
    for fg in filter(x -> !(x in no_group), fgroups)
        names = [t.name for t in sys.techs if t.functional_group==fg]
        names = map(n -> make_legal(replace(n, "." => "_")), names)
        println(io, "{ rank=same $(join(names, ' ')) }")
    end

    println(io, "}")

end


"""
   $TYPEDSIGNATURES

Writes a DOT file of a `System`. The resulting file can be visualized with GraphViz, e.g.:
 ```
 dot -Tpng file.dot -o graph.png
 ```

## Arguments
 - `no_group`: Array of functional groups which should not be grouped in the plot
 - `options`: String of _graphviz_ options

 """
function dot_file(sys::System, file::AbstractString, no_group::Array{String}=["S", "C", "T"], options::String="")

    open(file, "w") do f
        dot_format(sys, f, no_group, options)
    end
end

"""
    $TYPEDSIGNATURES

Returns a `String`` representing `System` in the GraphViz's dot format.

## Arguments
 - `no_group`: Array of functional groups which should not be grouped in the plot
 - `options`: String of _graphviz_ options
 """
function dot_string(sys::System, no_group::Array{String}=["S", "C", "T"], options::String="")
    io = IOBuffer()
    dot_format(sys, io, no_group, options)
    String(take!(io))
end
