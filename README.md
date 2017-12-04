# SanitationSystemMassFlow


Extension of the
[SanitationSystemBuilder](https://github.com/Eawag-SWW/SanitationSystemBuilder.jl)
package. It enables to
- finds all possible systems given a set of sanitation technologies
- calculates a (optionally stochastic) mass flow analysis for each system.


# Installation

1. Install [Julia](https://julialang.org/) version 0.6 or newer.

2. Then the `SanitationSystemMassFlow` package is installed with the Julia command:
```Julia
Pkg.clone("https://gitlab.com/scheidan/SanitationSystemMassFlow.git")
```

# Usage

```Julia

using SanitationSystemMassFlow

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

# -----------
# System

# system without
allSys, _ = build_all_systems([A, B], [C, D, E, F, G], storeDeadends=false)


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

    # deterministic
    m_outs = massflow(sys, M_in)
    @show entered(M_in, sys)
    @show recovered(m_outs)
    @show sum(lost(m_outs),2)

    # stochastic
    m_outs = massflow(sys, M_in, MC=true)
    @show entered(M_in, sys)
    @show recovered(m_outs)
    @show sum(lost(m_outs),2)


end


```
