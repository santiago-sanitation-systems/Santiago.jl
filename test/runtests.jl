using SanitationSystemMassFlow
using Test

const SSB = SanitationSystemMassFlow

@testset "System builder" begin
    include("system_builder_tests.jl")
end

@testset "Mass flows" begin
    include("massflow_tests.jl")
end
