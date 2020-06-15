## -------------------------------------------------------
## rudimentary test of user interface functions


# -----------
# 1) Import tech file

# we use the test data that come with teh package
input_tech_file_csv = joinpath(pkgdir(SanitationSystemMassFlow), "test/example_techs.csv")

sources, additional_sources, techs = importTechFile(input_tech_file_csv,
                                                    sourceGroup = "U",
                                                    sourceAddGroup = "Uadd",
                                                    sinkGroup = "D")
@test length(sources) == 2
@test length(additional_sources) == 0
@test length(techs) == 264


# -----------
# 2) Build all systems

allSys = santiago_build_systems(sources, techs);
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



# -----------
# 3) Mass flows

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
# 4) select systems

for n in 1:length(allSys)
    @test n == length(select_systems(allSys, n))
end

@test_throws ErrorException select_systems(allSys, length(allSys) + 1)
