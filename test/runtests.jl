using SanitationSystemMassFlow
using Base.Test

SSB = SanitationSystemMassFlow

@testset begin

    # -----------
    # techs

    A = Tech(String[], ["a1", "a2"], "A", "group1", 0.5,
             [0.5 0.5 0 0 0;
              0.5 0.5 0 0 0;
              0.5 0.5 0 0 0;
              0.5 0.5 0 0 0],
             [5, 20, 100, 1000])

    B = Tech(String[], ["b1"], "B", "group1", 0.5, [1.0 0 0 0;
                                                    1 0 0 0;
                                                    1 0 0 0;
                                                    1 0 0 0], [5, 20, 100, 1000.0])


    C = Tech(["a1"], ["c1"], "C", "group1", 0.5,
             [0.5 0.2 0.3 0;
              1.0 0 0 0;
              0.6 0 0 0.4;
              1.0 0 0 0], [5, 20, 100, 1000])
    D = Tech(["a2", "b1"], String["d1", "d2", "d3"], "D", "group1", 0.5,
             [0.1 0.1 0.8 0 0 0;
              0.6 0.3 0.1 0 0 0;
              0.0 0.0 1.0 0 0 0;
              0.5 0.5 0.0 0 0 0],
             [5, 20, 100, 1000])


    E = Tech(["c1", "d1"], String[], "E", "group1", 0.5, [1.0 0 0 0;
                                                          1.0 0 0 0;
                                                          1.0 0 0 0;
                                                          0.8 0 0 0.2], [5, 20, 100, 1000])
    F = Tech(["d2", "d3"], String[], "F", "group1", 0.5, [1.0 0 0 0;
                                                          1.0 0 0 0;
                                                          0.5 0.5 0 0;
                                                          1.0 0 0 0], [5, 20, 100, 1000])

    G = Tech(["a1", "a2", "b1"], String[], "G", "group1", 0.5, [0.0 0 0 1.0;
                                                                0.0 0 0 1.0;
                                                                0.0 0.5 0.5 0;
                                                                0.0 1.0 0 0])



    @test length(SSB.get_inputs([A])) == 0
    @test length(SSB.get_inputs([A,D])) == 2
    @test length(SSB.get_inputs([A,D,E])) == 4

    @test length(SSB.get_outputs([A])) == 2
    @test length(SSB.get_outputs([A,D])) == 5
    @test length(SSB.get_outputs([A,D,E])) == 5



    # -----------
    # System

    # system without  triangle
    allSys = build_all_systems([A, B], [C, D, E, F, G])
    @test length(allSys) == 2


    # -----------
    # Mass flow

    # define input masses for each source
    massesA = Float64[600;
                      400;
                      260;
                      90]

    massesB = Float64[1405;
                      760;
                      600;
                      110]

    M_in = Dict(A => massesA, B => massesB)


    # test mass balances
    for sys in allSys
        m_outs = massflow(sys, M_in)
        @test entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs),2) ≈ [0.0, 0.0, 0.0, 0.0]

        m_outs = massflow(sys, M_in, MC=true)
        @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs),2),
                       [0.0, 0.0, 0.0, 0.0], atol=1e-12)

        m_outs = massflow(sys, M_in, MC=true, scale_reliability=100)
        @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs),2),
                       [0.0, 0.0, 0.0, 0.0], atol=1e-12)

    end



end
