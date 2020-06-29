using Santiago
using Test
using Logging
global_logger(ConsoleLogger(stderr, Logging.Error))

const SSB = Santiago

@testset "Appropriateness assessment" begin
    include("appropriateness_test.jl")
end

@testset "System builder" begin
    include("system_builder_tests.jl")
end

@testset "Mass flows" begin
    include("massflow_tests.jl")
end

@testset "Import/export" begin
    include("import_export_test.jl")
end

@testset "User interface" begin
    include("user_interface_tests.jl")
end
