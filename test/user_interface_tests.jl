## -------------------------------------------------------
## rudimentary test of user interface functions

# -----------
# 1a) Import tech file

# we use the test data that come with the package
input_tech_file = joinpath(pkgdir(Santiago), "test/example_techs.json")
sources, additional_sources, techs = import_technologies(input_tech_file)

@test length(sources) == 2
@test length(additional_sources) == 0
@test length(techs) == 264

for t in techs
    @test t.appscore[1] ≈ -1.0 # default value
end

# add appropriateness
input_case_file = joinpath(pkgdir(Santiago), "test/example_case.json")
tas, tas_components = appropriateness(input_tech_file, input_case_file)
update_appropriateness!(techs, tas)

for t in techs
    @test t.appscore[1] >= 0
end



# -----------
# 1b) Import tech file and calcualte appropriateness together

# we use the test data that come with the package
input_tech_file = joinpath(pkgdir(Santiago), "test/example_techs.json")
input_case_file = joinpath(pkgdir(Santiago), "test/example_case.json")

sources, additional_sources, techs = import_technologies(input_tech_file, input_case_file)

@test length(sources) == 2
@test length(additional_sources) == 0
@test length(techs) == 264


# -----------
# 2) Build all systems

allSys = build_systems(sources, techs);
@test length(allSys) == 35


# -----------
# 3) Calculate (or update) system properties

@test "ID" in keys(allSys[1].properties)
@test "source" in keys(allSys[1].properties)

sysappscore!.(allSys)
@test "sysappscore" in keys(allSys[1].properties)

connectivity!.(allSys)
@test "connectivity" in keys(allSys[1].properties)

ntechs!.(allSys)
@test "ntechs" in keys(allSys[1].properties)

template!.(allSys)
@test "template" in keys(allSys[1].properties)

# no mass flow information yet
@test_throws ErrorException properties_dataframe(allSys,
                                                 massflow_selection = ["recovered | water | mean"])

# -----------
# 4) Mass flows

input_masses = Dict("Dry.toilet" => Dict("phosphor" => 548.0,
                                         "nitrogen" => 4550.0,
                                         "water" => 22447113.5,
                                         "totalsolids" => 32120.0),
                    "Pour.flush" => Dict("phosphor" => 548.0,
                                         "nitrogen" => 4550.0,
                                         "water" => 1277113.465,
                                         "totalsolids" => 32120.0)
                    )

# calculate mass flows for all systems and write to system properties
massflow_summary!.(allSys, Ref(input_masses), n=20)
@test "massflow_stats" in keys(allSys[1].properties)
@test length(keys(allSys[1].properties["massflow_stats"])) == 5



# -----------
# 5) select systems

for n in 1:length(allSys)
    @test n == length(select_systems(allSys, n))
end

@test_throws ErrorException select_systems(allSys, length(allSys) + 1)


# -----------
# 6) DataFrame properties

df = properties_dataframe(allSys,
                          massflow_selection = ["recovered|water|mean",
                                                "recovered|  water |sd",
                                                "lost | water   |  air loss| q_0.5",
                                                "entered | water"])
@test size(df,1) == length(allSys)
@test "ID" in names(df)
@test "recovered_water_mean" in names(df)
@test "recovered_water_sd" in names(df)
@test "lost_water_air loss_q_0.5" in names(df)
@test "entered_water" in names(df)
