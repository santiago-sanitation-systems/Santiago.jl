# -----------
# functions to calculate system properties

export sysappscore, sysappscore!,
    ntechs, ntechs!,
    nconnections, nconnections!,
    connectivity, connectivity!,
    template, template!,
    templates_per_tech, techs_per_template

# -----------
"""
    $TYPEDSIGNATURES

Compute the system appropriateness score (SAS).
`α` ∈ [0, 1] gradually changes from the arithmetic mean (α=0) to the
 a geometric mean (`α=1`).
"""
function sysappscore(s::System; α = 0.5)::Float64

    appscores = Float64[]
    for component in s.techs
        append!(appscores, component.appscore)
    end

    # return -1 for negative TAS
    any(appscores .< 0) && return -1.0

    n = length(appscores)
    logsum = sum(Base.log.(appscores))
    score = exp( logsum/(α*(n-1.0) + 1.0) )
    return score
end

"""
    $TYPEDSIGNATURES

Add the system appropriateness score (SAS) to a system. `α` ∈ [0, 1] gradually
changes from the arithmetic mean (α=0) to the a geometric mean (`α=1`).
"""
sysappscore!(s::System; α = 0.5) = s.properties["sysappscore"] = sysappscore(s, α=α)


# -----------
"""
    $TYPEDSIGNATURES
Calculate number of technologies.
"""
ntechs(s::System) = length(s.techs)

"""
    $TYPEDSIGNATURES
Add number of technologies to system properties.
"""
ntechs!(s::System) = s.properties["ntechs"] = ntechs(s)


# -----------
"""
    $TYPEDSIGNATURES
Calculate number of connections.
"""
nconnections(s::System) = length(s.connections)

"""
    $TYPEDSIGNATURES
Add number of connections to system properties.
"""
nconnections!(s::System) = s.properties["nconnections"] = nconnections(s)


# -----------
"""
    $TYPEDSIGNATURES
Calculate average number of connection per technology.
"""
connectivity(s::System) = nconnections(s) / ntechs(s)

"""
    $TYPEDSIGNATURES
Add average number of connection per technology to system properties.
"""
connectivity!(s::System) = s.properties["connectivity"] = connectivity(s)

"""
    $TYPEDSIGNATURES
Generate a string with all source names
"""
function source_names(s::System)
    sources = get_sources(s)
    names_ss = [t.name for t in sources]
    sort!(names_ss)
    join(names_ss, "_")
end

"""
    $TYPEDSIGNATURES
Add a string with all source names to system properties.
"""
source_names!(s::System) = s.properties["source"] = source_names(s)

# -----------
# define system templates

function fg_t_transported(s::System)
    for t in s.techs
        if t.functional_group == :T && occursin("_trans", t.name)
            return true
        end
    end
    false
end


function fg_t_not_transported(s::System)
    for t in s.techs
        if t.functional_group == :T && !occursin("_trans", t.name)
            return true
        end
    end
    false
end


"""
    $TYPEDSIGNATURES
Calculate characteristics that are used to assign templaces
"""
function template_characteristics(s::System)
    # -----------
    # --- calculate  characteristics
    all_products = [c[1] for c in s.connections]
    all_product_names = lowercase.(string(p.name) for p in all_products)

    all_tech_names = unique([t.name for t in s.techs])
    all_functional_groups = string.(unique([t.functional_group for t in s.techs]))

    # dry_material
    dry_material = any(occursin.(Ref(r"^faeces$"), all_product_names)) ||
        any(occursin.(Ref(r"^excreta$"), all_product_names))

    # sludge
    has_sludge = any(occursin.("sludge", all_product_names))

    # onsite_sludge (searches only for the word "sludge")
    onsite_sludge = any(occursin.(Ref(r"^sludge$"), all_product_names))

    # blackwater
    blackwater = any(occursin.(Ref(r"blackwater$"), all_product_names))

    # transported_blackwater
    transported_blackwater = any(occursin.("transportedblackwater", all_product_names)) ||
        any(occursin.("transportedbrownwater", all_product_names))

    # urine
    urine = any(occursin.("urine", all_product_names))

    # onsite storage and treatment
    fg_s = any(occursin.("S", all_functional_groups))

    # decentralized treatment
    fg_t_notrans = fg_t_not_transported(s)

    # centralized treatment
    fg_t_trans = fg_t_transported(s)

    # transported
    has_transport = any(occursin.("transported", all_product_names))

    # biofuel
    has_biofuel = any(occursin.(Ref(r"^biogas$"), all_product_names)) ||
        any(occursin.(Ref(r"^briquettes$"), all_product_names)) ||
        any(occursin.("transportedbiogas", all_product_names)) ||
        any(occursin.("transportedbriquettes", all_product_names))

    # onsite_biofuel
    onsite_biofuel = any(occursin.(Ref(r"^biogas$"), all_product_names)) ||
        any(occursin.(Ref(r"^briquettes$"), all_product_names))

    # transported biofuel
    transported_biofuel = any(occursin.("transportedbiogas", all_product_names)) ||
        any(occursin.("transportedbriquettes", all_product_names))

    # biomnass
    biomass = any(occursin.("compost", all_product_names)) ||
        any(occursin.("stored_faeces", all_product_names))||
        any(occursin.("dried_faeces", all_product_names))||
        any(occursin.("biochar", all_product_names))||
        any(occursin.("pellets", all_product_names))||
        any(occursin.("pit_humus", all_product_names))

    # has urinal
    has_urinal = any(occursin.("urinal", all_tech_names))

    # controlled od
    rapidresponse = any(occursin.("controlled_od", all_tech_names)) ||
        any(occursin.("borehole", all_tech_names)) ||
        any(occursin.("trench", all_tech_names)) ||
        any(occursin.("chemical", all_tech_names))

    # container
    container = any(occursin.("container", all_tech_names))

    # Sink
    sink = any(occursin.("sink", all_tech_names)) ||
    any(occursin.("handwashing", all_tech_names))

    # Organic Waste Collection
    organicwastecoll = any(occursin.("organic_waste_collection", all_tech_names))

    #Stormwater Collection
    stormwatercollection = any(occursin.("stormwater_collection", all_tech_names))

    return (dry_material = dry_material,
            has_sludge = has_sludge,
            onsite_sludge = onsite_sludge,
            blackwater = blackwater,
            transported_blackwater = transported_blackwater,
            urine = urine,
            fg_s = fg_s,
            fg_t_notrans = fg_t_notrans,
            fg_t_trans = fg_t_trans,
            has_transport = has_transport,
            has_biofuel = has_biofuel ,
            onsite_biofuel =onsite_biofuel,
            transported_biofuel = transported_biofuel,
            biomass = biomass,
            has_urinal = has_urinal,
            rapidresponse = rapidresponse,
            container = container,
            sink = sink,
            organicwastecoll = organicwastecoll,
            stormwatercollectionn = stormwatercollection)

end

multiple_templates_error(s::System, t1, t2) = error("More than one template matchs system:\n$s \n-$(t1) \n-$(t2)")

"""
    $TYPEDSIGNATURES
Identifies the template a system belongs to.
"""
function template(s::System)
    # -----------
    # --- calculate some characteristics

    dry_material,
    has_sludge,
    onsite_sludge,
    blackwater,
    transported_blackwater,
    urine,
    fg_s,
    fg_t_notrans,
    fg_t_trans,
    has_transport,
    has_biofuel,
    onsite_biofuel,
    transported_biofuel,
    biomass,
    has_urinal,
    rapidresponse,
    container,
    sink,
    organicwastecoll,
    stormwatercollection  = template_characteristics(s)

    # -----------
    # --- assigns template
    template = "Not classified"


    # -----------
    # dry

    if dry_material && onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && ! has_biofuel &&
        ! biomass && ! has_urinal && ! rapidresponse
        tt = "ST1. Onsite dry system with sludge production without biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && ! has_biofuel &&
        biomass && ! has_urinal && ! rapidresponse
        tt = "ST2. Onsite dry system with sludge production and with biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_t_notrans && ! fg_t_trans && ! has_biofuel &&
        ! biomass && ! has_urinal && ! rapidresponse
        tt = "ST3. Onsite dry system without sludge production without biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && ! has_biofuel &&
        biomass && ! has_urinal && ! rapidresponse
        tt = "ST4. Onsite dry system without sludge production and with biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_t_notrans && ! fg_t_trans && ! has_biofuel &&
        ! biomass && ! has_urinal && ! rapidresponse
        tt = "ST5. Decentralized dry system without biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_t_notrans && ! fg_t_trans && ! has_biofuel &&
        biomass && ! has_urinal && ! rapidresponse
        tt = "ST6. Decentralized dry system with biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && (fg_s || fg_t_notrans) && fg_t_trans && ! has_biofuel &&
        ! biomass && ! has_urinal && ! rapidresponse
        tt = "ST7. Hybrid dry system without biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && (fg_s || fg_t_notrans) && fg_t_trans && ! has_biofuel &&
        biomass && ! has_urinal && ! rapidresponse
        tt = "ST8. Hybrid dry system with biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_s && ! fg_t_notrans && fg_t_trans && ! has_biofuel &&
        ! biomass && ! has_urinal && ! rapidresponse
        tt = "ST9. Centralized dry system without biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_s && ! fg_t_notrans && fg_t_trans && ! has_biofuel &&
        biomass && ! has_urinal && ! rapidresponse
        tt = "ST10. Centralized dry system with biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && container && ! has_urinal && ! rapidresponse
        tt = "ST11. Centralized dry system with biomass production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    # -----------
    # Blackwater

    if ! onsite_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST12. Onsite blackwater system without sludge with or without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if onsite_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST13. Onsite blackwater system with sludge production without effuent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_t_notrans && ! fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST14. Decentralized blackwater system with sludge"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! has_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_t_notrans && ! fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST15. Decentralized blackwater system without sludge"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_sludge && blackwater &&
        ! urine && (fg_s || fg_t_notrans) && fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST16. Hybrid blackwater system with sludge"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_sludge && blackwater &&
        ! urine && ! fg_s && ! fg_t_notrans && fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST17. Centralized blackwater system with sludge"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! has_sludge && blackwater &&
        ! urine && (fg_s || fg_t_notrans) && fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST18. Hybrid blackwater system without sludge"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end
    if ! has_sludge && blackwater &&
        ! urine && ! fg_s && ! fg_t_notrans && fg_t_trans && ! has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST19. Centralized blackwater system without sludge"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end
    # -----------
    # Biofuel

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && onsite_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST20. Onsite dry system with biofuel production without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        ! urine && fg_s && ! fg_t_notrans && ! fg_t_trans && onsite_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST21. Onsite blackwater system with biofuel production without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_t_notrans && ! fg_t_trans && onsite_biofuel && ! transported_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST22. Decentralized dry system with biofuel production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        ! urine && fg_t_notrans && ! fg_t_trans && onsite_biofuel && ! transported_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST23. Decentralized blackwater system with biofuel production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && (fg_s || fg_t_notrans) && fg_t_trans && has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST24. Hybrid dry system with biofuel production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_s && ! fg_t_notrans && fg_t_trans && has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST25. Centralized dry system with biofuel production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        ! urine && (fg_s || fg_t_notrans) && fg_t_trans && has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST26. Hybrid blackwater system with biofuel production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end


    if ! dry_material && blackwater &&
        ! urine && ! fg_s && ! fg_t_notrans && fg_t_trans && has_biofuel && ! has_urinal && ! rapidresponse
        tt = "ST27. Centralized blackwater system with biofuel production"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    # -----------
    # Urine

    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && fg_s && ! fg_t_notrans && ! fg_t_trans &&  ! has_urinal && ! rapidresponse
        tt = "ST28. Onsite dry system with urine diversion without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater && ! transported_blackwater &&
        urine && fg_s && ! fg_t_notrans && ! fg_t_trans &&  ! has_urinal && ! rapidresponse
        tt = "ST29. Onsite blackwater system with urine diversion system without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && fg_t_notrans && ! fg_t_trans && ! has_urinal && ! rapidresponse
        tt = "ST30. Decentralized dry system with urine diversion with or without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        urine && fg_t_notrans && ! fg_t_trans && ! has_urinal && ! rapidresponse
        tt = "ST31. Decentralized blackwater system with urine diversion with or without effluent transport"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && (fg_s || fg_t_notrans) && fg_t_trans && ! has_urinal && ! rapidresponse
        tt = "ST32. Hybrid dry system with urine diversion"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end
    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && ! fg_s && ! fg_t_notrans && fg_t_trans &&! has_urinal && ! rapidresponse
        tt = "ST33. Centralized dry system with urine diversion"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        urine && (fg_s || fg_t_notrans) && fg_t_trans && ! has_urinal && ! rapidresponse
        tt = "ST34. Hybrid blackwater system with urine diversion"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end
    if ! dry_material && blackwater &&
        urine && ! fg_s && ! fg_t_notrans && fg_t_trans && ! has_urinal && ! rapidresponse
        tt = "ST35. Centralized blackwater system with urine diversion"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    # -----------
    # Others

    if rapidresponse && ! has_urinal
        tt = "ST36. Rapid emergency sanitation"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_urinal
        tt = "ST37. Urinal"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if sink
        tt = "ST38. Handwashing and sinks"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if organicwastecoll
        tt = "ST39. Organic waste collection"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    if stormwatercollection
        tt = "ST40. Stormwater collection"
        template = template == "Not classified" ? tt : multiple_templates_error(s, template, tt)
    end

    return template
end

"""
    $TYPEDSIGNATURES
Add the template to system properties.
"""
template!(s::System) = s.properties["template"] = template(s)



## ---------------------------------
## functions to relate templates and technolgies

"""
    $TYPEDSIGNATURES

List for every technology (including sources) the system templates it was used in.
Note, only technologies that are used in at least one system are listed.
"""
function templates_per_tech(systems::Array{System})
    haskey(systems[1].properties, "template") ||
        error("No templates assigned! Run `template!` first.")
    d = Dict{String, Set{String}}()
    for s in systems
        for tech in s.techs
            name = Santiago.simplifytechname(tech.name)
            if haskey(d, name)
                push!(d[name], s.properties["template"])
            else
                d[name] = Set([s.properties["template"]])
            end
        end
    end
    d
end

"""
    $TYPEDSIGNATURES

List all technologies (including sources) that are used by the systems of each templates.
"""
function techs_per_template(systems::Array{System})
    haskey(systems[1].properties, "template") ||
        error("No templates assigned! Run `template!` first.")
    d = Dict{String, Set{String}}()
    for s in systems
        templ = s.properties["template"]
        for tech in s.techs
            techname = Santiago.simplifytechname(tech.name)
            if haskey(d, templ)
                push!(d[templ], techname)
            else
                d[templ] = Set([techname])
            end
        end
    end
    d
end
