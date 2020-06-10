using SanitationSystemMassFlow
using Test
using Logging
global_logger(ConsoleLogger(stderr, Logging.Error))

const SSB = SanitationSystemMassFlow


@testset "System builder" begin
    include("system_builder_tests.jl")
end

@testset "Mass flows" begin
    include("massflow_tests.jl")
end

@testset "User interface" begin
    include("user_interface_tests.jl")
end
