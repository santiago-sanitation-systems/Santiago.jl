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

    # decentralized and centralized storage and treatment
    fg_t = any(occursin.("T", all_functional_groups))

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
    controlled_od = any(occursin.("controlled_od", all_tech_names))

    return (dry_material = dry_material,
            has_sludge = has_sludge,
            onsite_sludge = onsite_sludge,
            blackwater = blackwater,
            transported_blackwater = transported_blackwater,
            urine = urine,
            fg_s = fg_s,
            fg_t = fg_t,
            has_transport = has_transport,
            has_biofuel = has_biofuel ,
            onsite_biofuel =onsite_biofuel,
            transported_biofuel = transported_biofuel,
            biomass = biomass,
            has_urinal = has_urinal,
            controlled_od =controlled_od)

end

multible_templates_error(s::System, t1, t2) = error("More than one template matchs system:\n$s \n-$(t1) \n-$(t2)")

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
    fg_t,
    has_transport,
    has_biofuel,
    onsite_biofuel,
    transported_biofuel,
    biomass,
    has_urinal,
    controlled_od  = template_characteristics(s)

    # -----------
    # --- assigns template
    template = "not defined"


    # -----------
    # dry

    if dry_material && onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && ! has_biofuel &&
        ! biomass && ! has_urinal && ! controlled_od
        tt = "ST1. Onsite dry system with sludge production without biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && ! has_biofuel &&
        biomass && ! has_urinal && ! controlled_od
        tt = "ST2. Onsite dry system with sludge production and with biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_t && ! has_transport && ! has_biofuel &&
        ! biomass && ! has_urinal && ! controlled_od
        tt = "ST3. Onsite dry system without sludge production without biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! onsite_sludge && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && ! has_biofuel &&
        biomass && ! has_urinal && ! controlled_od
        tt = "ST4. Onsite dry system without sludge production and with biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_t && ! has_transport && ! has_biofuel &&
        ! biomass && ! has_urinal && ! controlled_od
        tt = "ST5. Decentralized dry system without biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_t && ! has_transport && ! has_biofuel &&
        biomass && ! has_urinal && ! controlled_od
        tt = "ST6. Decentralized dry system with biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && has_transport && ! has_biofuel &&
        ! biomass && ! has_urinal && ! controlled_od
        tt = "ST7. Hybrid dry system without biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && has_transport && ! has_biofuel &&
        biomass && ! has_urinal && ! controlled_od
        tt = "ST8. Hybrid dry system with biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_s && has_transport && ! has_biofuel &&
        ! biomass && ! has_urinal && ! controlled_od
        tt = "ST9. Centralized dry system without biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && ! fg_s && has_transport && ! has_biofuel &&
        biomass && ! has_urinal && ! controlled_od
        tt = "ST10. Centralized dry system with biomass production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    # -----------
    # Blackwater

    if ! onsite_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST11. Onsite blackwater system without sludge with or without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if onsite_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST12. Onsite blackwater system with sludge production without effuent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_t && ! has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST13. Decentralized blackwater system with sludge"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! has_sludge && blackwater && ! transported_blackwater &&
        ! urine && fg_t && ! has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST14. Decentralized blackwater system without sludge"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_sludge && blackwater &&
        ! urine && fg_s && has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST15. Hybrid blackwater system with sludge"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if has_sludge && blackwater &&
        ! urine && ! fg_s && has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST16. Centralized blackwater system with sludge"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! has_sludge && blackwater &&
        ! urine && fg_s && has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST17. Hybrid blackwater system without sludge"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end
    if ! has_sludge && blackwater &&
        ! urine && ! fg_s && has_transport && ! has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST18. Centralized blackwater system without sludge"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end
    # -----------
    # Biofuel

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && onsite_biofuel && ! has_urinal && ! controlled_od
        tt = "ST19. Onsite dry system with biofuel production without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        ! urine && fg_s && ! fg_t && ! has_transport && onsite_biofuel && ! has_urinal && ! controlled_od
        tt = "ST20. Onsite blackwater system with biofuel production without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_t && ! has_transport && onsite_biofuel && ! transported_biofuel && ! has_urinal && ! controlled_od
        tt = "ST21. Decentralized dry system with biofuel production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        ! urine && fg_t && ! has_transport && onsite_biofuel && ! transported_biofuel && ! has_urinal && ! controlled_od
        tt = "ST22. Decentralized blackwater system with biofuel production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && fg_s && has_transport && has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST23. Hybrid dry system with biofuel production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        ! urine && !fg_s && has_transport && has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST24. Centralized dry system with biofuel production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        ! urine && fg_s && has_transport && has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST25. Hybrid blackwater system with biofuel production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end


    if ! dry_material && blackwater &&
        ! urine && !fg_s && has_transport && has_biofuel && ! has_urinal && ! controlled_od
        tt = "ST26. Centralized blackwater system with biofuel production"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    # -----------
    # Urine

    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && fg_s && ! fg_t && ! has_transport && ! has_urinal && ! controlled_od
        tt = "ST27. Onsite dry system with urine diversion without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater && ! transported_blackwater &&
        urine && fg_s && ! fg_t && ! has_transport && ! has_urinal && ! controlled_od
        tt = "ST28. Onsite blackwater system with urine diversion system without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && fg_t && ! has_transport && ! has_urinal && ! controlled_od
        tt = "ST29. Decentralized dry system with urine diversion with or without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        urine && fg_t && ! has_transport && ! has_urinal && ! controlled_od
        tt = "ST30. Decentralized blackwater system with urine diversion with or without effluent transport"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && fg_s && has_transport && ! has_urinal && ! controlled_od
        tt = "ST31. Hybrid dry system with urine diversion"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end
    if dry_material && ! blackwater && ! transported_blackwater &&
        urine && !fg_s && has_transport && ! has_urinal && ! controlled_od
        tt = "ST32. Centralized dry system with urine diversion"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if ! dry_material && blackwater &&
        urine && fg_s && has_transport && ! has_urinal && ! controlled_od
        tt = "ST33. Hybrid blackwater system with urine diversion"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end
    if ! dry_material && blackwater &&
        urine && ! fg_s && has_transport && ! has_urinal && ! controlled_od
        tt = "ST34. Centralized blackwater system with urine diversion"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    # -----------
    # Others

    if ! dry_material && ! blackwater && ! transported_blackwater && urine && has_urinal && ! controlled_od
        tt = "ST35. Urinal"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
    end

    if controlled_od
        tt = "ST36. Controlled open defecation in humanitarian context"
        template = template == "not defined" ? tt : multiple_templates_error(s, template, tt)
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

List for every technology the system templates it was used in.
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

List all technologies that systems of the same templates have used.
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
