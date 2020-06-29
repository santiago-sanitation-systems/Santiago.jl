# -----------
# functios to asses and select systems

export sysappscore, sysappscore!,
    ntechs, ntechs!,
    connectivity, connectivity!,
    template, template!

# -----------
""" Compute the SAS of a system."""
function sysappscore(s::System; alpha::Float64 = 0.5)::Float64

    appscores = Float64[]
    for component in s.techs
        append!(appscores, component.appscore)
    end

    # return -1 for negative TAS
    any(appscores .< 0) && return -1.0

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
    # --- assigns template
    template = "not defined"

    # -----------
    # onsite simple systems

    if onsite_sludge & ! urine & ! transported_blackwater & ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        tt = "ST.1 Dry onsite storage with sludge production without effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if onsite_sludge & ! urine & ! transported_blackwater & effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        tt = "ST.2 Dry onsite storage with sludge production with effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if dry_material & ! onsite_sludge & ! urine & ! transported_blackwater &
        ! blackwater & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.3 Dry onsite storage and treatment without sludge production"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    # -----------
    # urine systems
    if onsite_sludge & urine & ! transported_blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        tt = "ST.4 Dry onsite storage without treatment with urine diversion without effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if onsite_sludge & urine & ! transported_blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        is_onsite_pit
        tt = "ST.5 Dry onsite storage without treatment with urine diversion with effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if dry_material & ! onsite_sludge & urine & ! transported_blackwater & ! blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char & ! is_onsite_pit
        tt = "ST.6 Dry onsite storage and treatment with urine diversion"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if dry_material & ! onsite_sludge & urine & ! transported_blackwater & blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char
        tt = "ST.7 Onsite blackwater without sludge and with urine diversion"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if urine & transported_blackwater & blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char
        tt = "ST.8 Offsite blackwater treatment with urine diversion"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    # -----------
    # biogas templates

    if ! transported_blackwater & ! effluent_transport & biogas_briq_char & ! transported_biogas_briq_char
        tt = "ST.9 Onsite biogas, briquettes or biochar without effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if ! transported_blackwater & effluent_transport & biogas_briq_char & ! transported_biogas_briq_char
        tt = "ST.10 Onsite biogas, briquettes or biochar with effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if ! transported_blackwater & transported_biogas_briq_char
        tt = "ST.11 Offsite biogas, briquettes or biochar without blackwater transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if transported_blackwater & transported_biogas_briq_char
        tt = "ST.12 Offsite biogas, briquettes or biochar with blackwater transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    # -----------
    # blackwater systems

    if dry_material & ! onsite_sludge & ! urine & ! transported_blackwater & blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.13 Onsite blackwater without sludge and without effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if dry_material & ! onsite_sludge & ! urine & ! transported_blackwater & blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.14 Onsite blackwater without sludge and with effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if onsite_sludge & ! transported_blackwater & blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.15 Onsite blackwater with sludge without effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if onsite_sludge & ! transported_blackwater & blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.16 Onsite blackwater with sludge and effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if ! dry_material & ! onsite_sludge & ! transported_blackwater & blackwater &
        ! effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.17 Onsite blackwater treatment without effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if ! dry_material & ! onsite_sludge & ! transported_blackwater & blackwater &
        effluent_transport & ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.18 Onsite blackwater treatment with effluent transport"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end

    if ! onsite_sludge & ! urine & transported_blackwater & blackwater &
        ! biogas_briq_char & ! transported_biogas_briq_char &
        ! is_onsite_pit
        tt = "ST.19 Offsite blackwater treatment"
        template = template == "not defined" ? tt : error("More than one template matchs system:\n$(template) \n(tt)")
    end


    return template
end

"""Add template to system properties"""
template!(s::System) = s.properties["template"] = template(s)
