


# -----------
# define technologies for testing

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

# --
# this shoud fail
transC_error = Dict{String, Dict{Product, Float64}}()
transC_error["phosphor"] = Dict(Product("recovered") => 0.0,
                                Product("airloss") => 0.0,
                                Product("soilloss") => 1.0,
                                Product("waterloss") => 1.0)
transC_error["nitrogen"] = Dict(Product("recovered") => 0.0,
                                Product("airloss") => 0.0,
                                Product("soilloss") => 0.0,
                                Product("waterloss") => 1.0)
transC_error["water"] = Dict(Product("recovered") => 0.0,
                             Product("airloss") => 0.5,
                             Product("soilloss") => 0.5,
                             Product("waterloss") => 0.0)
transC_error["totalsolids"] = Dict(Product("recovered") => 0.0,
                                   Product("airloss") => 1.0,
                                   Product("soilloss") => 0.0,
                                   Product("waterloss") => 0.0)

# -----------
# test systems builder function

@test_throws ErrorException Tech(["a1", "a2", "b1"], String[], "G", "group1", 0.5, transC_error, transC_rel)

@test length(SSB.get_inputs([A])) == 0
@test length(SSB.get_inputs([A,D])) == 2
@test length(SSB.get_inputs([A,D,E])) == 4

@test length(SSB.get_outputs([A])) == 2
@test length(SSB.get_outputs([A,D])) == 5
@test length(SSB.get_outputs([A,D,E])) == 5


# system without  triangle
allSys = build_all_systems([A, B], [C, D, E, F, G])
@test length(allSys) == 2
