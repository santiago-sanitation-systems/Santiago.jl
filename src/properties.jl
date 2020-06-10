# -----------
# functios to asses and select systems

export sysappscore, sysappscore!,
    ntechs, ntechs!,
    connectivity, connectivity!,
    template, template!

# -----------
""" Compute the SAS of a system."""
function sysappscore(s::System; alpha::Float64 = 0.5)

    appscores = Float64[]
    for component in s.techs
        append!(appscores, component.appscore)
    end

    n = length(appscores)
    logsum = sum(Base.log.(appscores))
    score = exp( logsum/(alpha*(n-1.0) + 1.0) )
    return score
end

"""Add SAS to system properties"""
sysappscore!(s::System) = s.properties["sysappscore"] = sysappscore(s)


# -----------
"""Calculate number of technologies"""
ntechs(s::System) = length(s.techs)

"""Add number of technologies to system properties"""
ntechs!(s::System) = s.properties["ntechs"] = ntechs(s)


# -----------
"""Calculate number of connection per technology"""
connectivity(s::System) = length(s.connections) / ntechs(s)

"""Add number of connection per technology to system properties"""
connectivity!(s::System) = s.properties["connectivity"] = connectivity(s)


# -----------
"""Identify to which template a sytem belongs"""
function template(s::System)

    # -----------
    # --- calculate some characteristics
    all_products = [c[1] for c in s.connections]
    all_product_names = [string(p.name) for p in all_products]

    all_tech_names = unique([t.name for t in s.techs])
    all_functional_groups = unique([t.functional_group for t in s.techs])

    # dry_material
    dry_material = any(occursin.("driedfaeces", all_product_names)) |
        any(occursin.("storedfaeces", all_product_names)) |
        any(occursin.("compost", all_product_names)) |
        any(occursin.("pithumus", all_product_names))

    # onsite_sludge (searches only for the word "sludge")
    onsite_sludge = any(occursin.(Ref(r"^sludge$"), all_product_names))

    # urine
    urine = any(occursin.("urine", all_product_names))

    # transported_blackwater
    transported_blackwater = any(occursin.("transportedblackwater", all_product_names)) |
        any(occursin.("transportedbrownwater", all_product_names))

    # blackwater
    blackwater = any(occursin.("blackwater", all_product_names))

    # effluent_transport
    effluent_transport = any([(occursin("effluent", string(cc[1].name)) &
                               occursin("sewer", lowercase(cc[3].name))) for cc in s.connections])

    # biogas or biochar or briquettes
    biogas_briq_char = any(occursin.("biogas", all_product_names)) |
        any(occursin.("biochar", all_product_names)) |
        any(occursin.("briquettes", all_product_names))

    # transported_biogas or biochar or briquettes
    transported_biogas_briq_char = any(occursin.("transportedbiogas", all_product_names)) |
        any(occursin.("transportedbiochar", all_product_names)) |
        any(occursin.("transportedbriquettes", all_product_names))

    # is_onsite_pit
    is_onsite_pit = any(occursin.("single", lowercase.(all_tech_names)))

    # -----------
    # --- assigns templates
    system_templates = String[]

    # -----------
    # onsite simple systems

    if onsite_sludge & ! urine & ! transported_blackwater & ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        push!(system_templates, "ST.1 Dry onsite storage with sludge production without effluent transport")
    end

    if onsite_sludge & ! urine & ! transported_blackwater & effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        push!(system_templates, "ST.2 Dry onsite storage with sludge production with effluent transport")
    end

    if dry_material & ! onsite_sludge & ! urine & ! transported_blackwater &
        ! blackwater & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.3 Dry onsite storage and treatment without sludge production")
    end

    # -----------
    # urine systems
    if onsite_sludge & urine & ! transported_blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        push!(system_templates, "ST.4 Dry onsite storage without treatment with urine diversion without effluent transport")
    end

    if onsite_sludge & urine & ! transported_blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        push!(system_templates, "ST.5 Dry onsite storage without treatment with urine diversion with effluent transport")
    end

    if dry_material & ! onsite_sludge & urine & ! transported_blackwater & ! blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char & ! is_onsite_pit
        push!(system_templates, "ST.6 Dry onsite storage and treatment with urine diversion")
    end

    if dry_material & ! onsite_sludge & urine & ! transported_blackwater & blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char
        push!(system_templates, "ST.7 Onsite blackwater without sludge and with urine diversion")
    end

    if urine & transported_blackwater & blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char
        push!(system_templates, "ST.8 Offsite blackwater treatment with urine diversion")
    end

    # -----------
    # biogas templates

    if ! transported_blackwater & ! effluent_transport & biogas_briq_char & ! transported_biogas_briq_char
        push!(system_templates, "ST.9 Onsite biogas, briquettes or biochar without effluent transport")
    end

    if ! transported_blackwater & effluent_transport & biogas_briq_char & ! transported_biogas_briq_char
        push!(system_templates, "ST.10 Onsite biogas, briquettes or biochar with effluent transport")
    end

    if ! transported_blackwater & transported_biogas_briq_char
        push!(system_templates, "ST.11 Offsite biogas, briquettes or biochar without blackwater transport")
    end

    if transported_blackwater & transported_biogas_briq_char
        push!(system_templates, "ST.12 Offsite biogas, briquettes or biochar with blackwater transport")
    end

    # -----------
    # blackwater systems

    if dry_material & ! onsite_sludge & ! urine & ! transported_blackwater & blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.13 Onsite blackwater without sludge and without effluent transport")
    end

    if dry_material & ! onsite_sludge & ! urine & ! transported_blackwater & blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.14 Onsite blackwater without sludge and with effluent transport")
    end

    if onsite_sludge & ! transported_blackwater & blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.15 Onsite blackwater with sludge without effluent transport")
    end

    if onsite_sludge & ! transported_blackwater & blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.16 Onsite blackwater with sludge and effluent transport")
    end

    if ! dry_material & ! onsite_sludge & ! transported_blackwater & blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.17 Onsite blackwater treatment without effluent transport")
    end

    if ! dry_material & ! onsite_sludge & ! transported_blackwater & blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.18 Onsite blackwater treatment with effluent transport")
    end

    if ! onsite_sludge & ! urine & transported_blackwater & blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        push!(system_templates, "ST.19 Offsite blackwater treatment")
    end

    # -----------
    # no template (NA)

    if length(system_templates)==0
        push!(system_templates, "not defined")
    end

    return system_templates
end

"""Add template to system properties"""
template!(s::System) = s.properties["template"] = template(s)
