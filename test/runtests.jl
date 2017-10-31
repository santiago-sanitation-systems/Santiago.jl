using SanitationSystemBuilder
using Base.Test

SSB = SanitationSystemBuilder

@testset begin

    # -----------
    # techs


    A = Tech(String[], ["a1", "a2"], "A", "group1", 0.5)
    B = Tech(String[], ["b1"], "B", "group1", 0.5)

    # techs and sinks
    C = Tech(["a1"], String["c1", "c2"], "C", "group1", 0.5)
    D = Tech(["a2", "c2", "b2"], String["d1", "d2", "d3"], "D", "group1", 0.5)

    C2 = Tech(["a1"], String["c1"], "C", "group1", 0.5)
    D2 = Tech(["a2", "b1"], String["d1", "d2", "d3"], "D", "group1", 0.5)

    E = Tech(["c1", "d1"], String[], "E", "group1", 0.5)
    F = Tech(["d2", "d3"], String[], "F", "group1", 0.5)


    @test length(SSB.get_inputs([A])) == 0
    @test length(SSB.get_inputs([A,D])) == 3
    @test length(SSB.get_inputs([A,D,E])) == 5

    @test length(SSB.get_outputs([A])) == 2
    @test length(SSB.get_outputs([A,D])) == 5
    @test length(SSB.get_outputs([A,D,E])) == 5

    c1 = SSB.get_candidates([C2,D2,E,F], SSB.get_outputs([A,B]), 1)
    c2 = SSB.get_candidates([C2,D2,E,F], SSB.get_outputs([A,B]), 2)


    # -----------
    # System

    # system without  triangle
    allSys, _ = build_all_systems([A, B], [C2, D2, E, F], storeDeadends=false)
    @test length(allSys) == 1

    # This system cannot be found with the current algorithm (triangle!)
    # connection between A, C, and D
    allSys, _ = build_all_systems([A, B], [C, D, E, F], storeDeadends=false)
    @test_skip length(allSys) == 1

end
