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


end
