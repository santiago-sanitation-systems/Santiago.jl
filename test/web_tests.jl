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
for s in allSys
    @test SSB.sysappscore_web(s, tas) ≈ sysappscore(s)
end
