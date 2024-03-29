## -------------------------------------------------------
##
## File: web_test.jl
##
## September 17, 2021 -- Andreas Scheidegger
## andreas.scheidegger@eawag.ch
## -------------------------------------------------------

# we use the test data that come with the package
input_tech_file = joinpath(pkgdir(Santiago), "test/example_techs.json")
sources, additional_sources, techs = import_technologies(input_tech_file)

allSys = build_systems(sources, techs)
@test length(allSys) == 76

# error because sysstem properties are missing
@test_throws ErrorException SSB.select_systems_web(allSys, 33, tas, target = "sysappscore", selection_type = "ranking")

ntechs!.(allSys)
connectivity!.(allSys)
template!.(allSys)

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
massflow_summary!.(allSys, Ref(input_masses), n=10)


# add appropriateness
input_case_file = joinpath(pkgdir(Santiago), "test/example_case.json")
tas, tas_components = appropriateness(input_tech_file, input_case_file)
update_appropriateness!(sources, tas)
update_appropriateness!(techs, tas)

# test sysappscore_web
@testset "sysappscore_web" begin
    for s in allSys
    @test SSB.sysappscore_web(s, tas) ≈ sysappscore(s)
    end
end



@testset "system selection web" begin

    for n in 0:length(allSys)
        @test n == length(SSB.select_systems_web(allSys, n, tas))
    end

    @test length(SSB.select_systems_web(allSys, length(allSys) + 1, tas)) == length(allSys)

    select1 = select_systems(allSys, 33, target = "sysappscore",
                             selection_type = "ranking")
    select2 = SSB.select_systems_web(allSys, 33, tas, target = "sysappscore",
                                     selection_type = "ranking")
    @test all(select1 .== select2)

    select1 = select_systems(allSys, 33, target = "connectivity",
                             selection_type = "ranking")
    select2 = SSB.select_systems_web(allSys, 33, tas, target = "connectivity",
                                     selection_type = "ranking")
    @test all(select1 .== select2)

    select1 = select_systems(allSys, 33, target = ("all" => "recovery_ratio"),
                             selection_type = "ranking")
    select2 = SSB.select_systems_web(allSys, 33, tas, target = ("all" => "recovery_ratio"),
                                     selection_type = "ranking")
    @test all(select1 .== select2)

end


@testset "JSON export web" begin

    nuser = 1
    for i in 1:length(allSys)
        @test JSON3.write(allSys[i], tas, nuser) == JSON3.write(allSys[i])
    end

    @test JSON3.write(allSys, tas, nuser) == JSON3.write(allSys)


    @test JSON3.write(scale_massflows(allSys[1], 5.0)) == JSON3.write(scale_massflows(allSys[1], 1.0), tas, 5.0)
    @test JSON3.write(scale_massflows.(allSys[1:3], 5.0)) == JSON3.write(scale_massflows.(allSys[1:3], 1.0), tas, 5.0)
end

@testset "techs_per_template" begin

    tt = Santiago.techs_per_template(allSys)
    ttweb = Santiago.techs_per_template_web(allSys)

    @test !any(occursin.("_trans", union(values(tt)...)))
    @test any(occursin.("_trans", union(values(ttweb)...)))
end
