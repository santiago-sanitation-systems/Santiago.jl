# test mass flow functions


# define input masses for each source
M_in = Dict("A" => Dict("phosphor" => 600,
                        "nitrogen" => 400,
                        "water" => 260,
                        "totalsolids" => 90),
            "B" => Dict("phosphor" => 60,
                        "nitrogen" => 40,
                        "water" => 26,
                        "totalsolids" => 9))


# test mass balances
for sys in allSys
    m_outs = massflow(sys, M_in)
    @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs), dims=2),
                   [0.0, 0.0, 0.0, 0.0],
                   atol=1e-12)

    m_outs = massflow(sys, M_in, MC=true)
    @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs), dims=2),
                   [0.0, 0.0, 0.0, 0.0], atol=1e-12)

    m_outs = massflow(sys, M_in, MC=true, scale_reliability=100)
    @test isapprox(entered(M_in, sys) - recovered(m_outs) - sum(lost(m_outs), dims=2),
                   [0.0, 0.0, 0.0, 0.0], atol=1e-12)

    # summary function
    m1 = massflow_summary(sys, M_in,
                          MC=true, n=10)
    @test length(m1) == 5
end
