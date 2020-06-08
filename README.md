# SanitationSystemMassFlow


Extension of the
[SanitationSystemBuilder](https://github.com/Eawag-SWW/SanitationSystemBuilder.jl)
package. It enables to
- find all possible systems given a set of sanitation technologies
- calculate (optionally stochastic) the mass flows for each system for total `phosphor`, total `nitrogen`, `totalsolids`, and `water`.


# Installation

1. Install [Julia](https://julialang.org/) version 1.x.

2. Then the `SanitationSystemMassFlow` package is installed from within the Julia:
```Julia
] add https://gitlab.com/scheidan/SanitationSystemMassFlow.git#updateJulia1.0

```

# Usage

Note, starting Julia with multiple threads may speed up the execution.

```Julia
using SanitationSystemMassFlow

# -----------
# define a few techs (this is typically not done by hand)

#-- defines the concetration factors of the transfer coefficients,
#   i.e. the larger the more uncertain are we about the values.
transC_rel = Dict{String, Float64}("phosphor" => 5.0,
                                   "nitrogen" => 20.0,
                                   "water" => 100.0,
                                   "totalsolids" => 1000.0)

# --
transC_A = Dict{String, Dict{Product, Float64}}()
transC_A["phosphor"] = Dict(Product("a1") => 0.5,
                            Product("a2") => 0.5,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_A["nitrogen"] = Dict(Product("a1") => 0.5,
                            Product("a2") => 0.5,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_A["water"] = Dict(Product("a1") => 0.5,
                         Product("a2") => 0.5,
                         Product("airloss") => 0.0,
                         Product("soilloss") => 0.0,
                         Product("waterloss") => 0.0)
transC_A["totalsolids"] = Dict(Product("a1") => 0.5,
                               Product("a2") => 0.5,
                               Product("airloss") => 0.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.0)


A = Tech(String[], ["a1", "a2"], "A", "group1", 0.5,
         transC_A,
         transC_rel)

# --
transC_B = Dict{String, Dict{Product, Float64}}()
transC_B["phosphor"] = Dict(Product("b1") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_B["nitrogen"] = Dict(Product("b1") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_B["water"] = Dict(Product("b1") => 1.0,
                         Product("airloss") => 0.0,
                         Product("soilloss") => 0.0,
                         Product("waterloss") => 0.0)
transC_B["totalsolids"] = Dict(Product("b1") => 1.0,
                               Product("airloss") => 0.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.0)

B = Tech(String[], ["b1"], "B", "group1", 0.5, transC_B, transC_rel)

# --
transC_C = Dict{String, Dict{Product, Float64}}()
transC_C["phosphor"] = Dict(Product("c1") => 0.5,
                            Product("airloss") => 0.2,
                            Product("soilloss") => 0.3,
                            Product("waterloss") => 0.0)
transC_C["nitrogen"] = Dict(Product("c1") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_C["water"] = Dict(Product("c1") => 0.6,
                         Product("airloss") => 0.0,
                         Product("soilloss") => 0.0,
                         Product("waterloss") => 0.4)
transC_C["totalsolids"] = Dict(Product("c1") => 1.0,
                               Product("airloss") => 0.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.0)
C = Tech(["a1"], ["c1"], "C", "group1", 0.5,
         transC_C, transC_rel)

# --

transC_D = Dict{String, Dict{Product, Float64}}()
transC_D["phosphor"] = Dict(Product("d1") => 0.1,
                            Product("d2") => 0.1,
                            Product("d3") => 0.8,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_D["nitrogen"] = Dict(Product("d1") => 0.3,
                            Product("d2") => 0.3,
                            Product("d3") => 0.1,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.3,
                            Product("waterloss") => 0.0)
transC_D["water"] = Dict(Product("d1") => 0.0,
                         Product("d2") => 0.0,
                         Product("d3") => 1.0,
                         Product("airloss") => 0.0,
                         Product("soilloss") => 0.0,
                         Product("waterloss") => 0.0)
transC_D["totalsolids"] = Dict(Product("d1") => 0.5,
                               Product("d2") => 0.5,
                               Product("d3") => 0.0,
                               Product("airloss") => 0.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.0)

D = Tech(["a2", "b1"], String["d1", "d2", "d3"], "D", "group1", 0.5,
         transC_D, transC_rel)

# --
transC_E = Dict{String, Dict{Product, Float64}}()
transC_E["phosphor"] = Dict(Product("recovered") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_E["nitrogen"] = Dict(Product("recovered") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_E["water"] = Dict(Product("recovered") => 1.0,
                         Product("airloss") => 0.0,
                         Product("soilloss") => 0.0,
                         Product("waterloss") => 0.0)
transC_E["totalsolids"] = Dict(Product("recovered") => 0.8,
                               Product("airloss") => 0.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.2)

E = Tech(["c1", "d1"], String[], "E", "group1", 0.5, transC_E, transC_rel)

# --

transC_F = Dict{String, Dict{Product, Float64}}()
transC_F["phosphor"] = Dict(Product("recovered") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_F["nitrogen"] = Dict(Product("recovered") => 1.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 0.0)
transC_F["water"] = Dict(Product("recovered") => 0.5,
                         Product("airloss") => 0.5,
                         Product("soilloss") => 0.0,
                         Product("waterloss") => 0.0)
transC_F["totalsolids"] = Dict(Product("recovered") => 1.0,
                               Product("airloss") => 0.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.0)

F = Tech(["d2", "d3"], String[], "F", "group1", 0.5, transC_F, transC_rel)

# --

transC_G = Dict{String, Dict{Product, Float64}}()
transC_G["phosphor"] = Dict(Product("recovered") => 0.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 1.0)
transC_G["nitrogen"] = Dict(Product("recovered") => 0.0,
                            Product("airloss") => 0.0,
                            Product("soilloss") => 0.0,
                            Product("waterloss") => 1.0)
transC_G["water"] = Dict(Product("recovered") => 0.0,
                         Product("airloss") => 0.5,
                         Product("soilloss") => 0.5,
                         Product("waterloss") => 0.0)
transC_G["totalsolids"] = Dict(Product("recovered") => 0.0,
                               Product("airloss") => 1.0,
                               Product("soilloss") => 0.0,
                               Product("waterloss") => 0.0)

G = Tech(["a1", "a2", "b1"], String[], "G", "group1", 0.5, transC_G, transC_rel)



# -----------
# Find all systems


# build systems
allSys = build_all_systems([A, B], [C, D, E, F, G])


# -----------
# Calculate massflows

# define input masses for each source
M_in = Dict("A" => Dict("phosphor" => 600,
                        "nitrogen" => 400,
                        "water" => 260,
                        "totalsolids" => 90),
            "B" => Dict("phosphor" => 60,
                        "nitrogen" => 40,
                        "water" => 26,
                        "totalsolids" => 9))


# calculate massflow for each system
for sys in allSys
    sys.properties["mf_stats"] = massflow_summary(sys, M_in,
                                                  MC=true, n=30)
end

# example how to extract results
allSys[2].properties["mf_stats"]["entered"]
allSys[2].properties["mf_stats"]["recovery_ratio"]
allSys[2].properties["mf_stats"]["recovered"]

allSys[2].properties["mf_stats"]["lost"][:,"air loss",:]
allSys[2].properties["mf_stats"]["lost"][:,:,"mean"]
allSys[2].properties["mf_stats"]["lost"][:,:,"q_0.5"]
```
