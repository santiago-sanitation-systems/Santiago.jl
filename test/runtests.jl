using SanitationSystemBuilder
using Base.Test

SSB = SanitationSystemBuilder

@testset begin

    # -----------
    # techs

    # 3 substances + 2 losses

    # sources
    massesA = Float64[505 600;
                      340 400;
                      140 260;
                      80 90]
    A = Tech(String[], ["a1", "a2"], "A", "group1", 0.5, Mout=massesA)

    massesB = Float64[1405;
                      760;
                      600;
                      110][:,:]
    B = Tech(String[], ["b1"], "B", "group1", 0.5, Mout=massesB)


    # techs and sinks
    C = Tech(["a1"], ["c1"], "C", "group1", 0.5,
             transC=[0.5 0.2 0.3;
                     1.0 0 0;
                     1.0 0 0;
                     1.0 0 0])
    D = Tech(["a2", "b1"], String["d1", "d2", "d3"], "D", "group1", 0.5,
             transC=[0.1 0.1 0.8 0 0;
                     0.6 0.3 0.1 0 0;
                     0.0 0.0 1.0 0 0;
                     0.5 0.5 0.0 0 0])


    E = Tech(["c1", "d1"], String[], "E", "group1", 0.5, transC=[1.0 0 0;
                                                                 1.0 0 0;
                                                                 1.0 0 0;
                                                                 1.0 0 0])
    F = Tech(["d2", "d3"], String[], "F", "group1", 0.5, transC=[1.0 0 0;
                                                                 1.0 0 0;
                                                                 1.0 0 0;
                                                                 1.0 0 0])



    @test length(SSB.get_inputs([A])) == 0
    @test length(SSB.get_inputs([A,D])) == 2
    @test length(SSB.get_inputs([A,D,E])) == 4

    @test length(SSB.get_outputs([A])) == 2
    @test length(SSB.get_outputs([A,D])) == 5
    @test length(SSB.get_outputs([A,D,E])) == 5



    # -----------
    # System

    # system without  triangle
    allSys, _ = build_all_systems([A, B], [C, D, E, F], storeDeadends=false)
    @test length(allSys) == 1


    # -----------
    # Mass flow
    sys = deepcopy(allSys[1])

    SanitationSystemBuilder.propagate_M!(sys)

    Mout_C = collect(filter(t -> t.name == "C", sys.techs))[1].Mout
    Mout_E = collect(filter(t -> t.name == "E", sys.techs))[1].Mout
    Mout_F = collect(filter(t -> t.name == "F", sys.techs))[1].Mout

    @test Mout_C[1,2:end] ≈ [101.0, 151.5]
    @test Mout_E[:,1] ≈ [705.5 - 101.0 - 151.5, 1036.0, 140.0, 180.0]
    @test Mout_F[:,1] ≈ [1804.5, 464.0, 860.0, 100.0]



end
