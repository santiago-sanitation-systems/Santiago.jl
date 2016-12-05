using SanitationSystemBuilder
using Base.Test

# -----------
# techs

techs1 = [
    Tech(String[], ["aa", "bb"], "one", "g1"),
    Tech(["aa"], ["dd"], "two", "g2"),
    Tech(["bb", "cc"], ["gg"], "three", "g3"),
    Tech(["dd"], ["cc", "ee", "ff"], "four", "g3"),
    Tech(["ff", "gg"], ["hh"], "five", "g3"),
    Tech(["ee"], String[], "six", "g4"),
    Tech(["hh"], ["ii"], "seven", "g5"),
    Tech(["ii"], String[], "eight", "g6")
]

techs2 = [
    Tech(String[], ["aa"], "one", "g1"),
    Tech(["aa", "dd"], ["bb"], "two", "g2"),
    Tech(["bb"], ["cc", "dd"], "three", "g2"),
    Tech(["cc"], String[], "four", "g3")
]

# tranport loop problem?
techs2_2 = [
    techs2...,
    Tech(["bb"], ["bb"], "t1", "g_transport"),
    Tech(["cc"], ["cc"], "t2", "g_transport"),
    Tech(["dd"], ["dd"], "t3", "g_transport")
]


# print
println(techs2[1])
println(techs2[2])
println(techs2[4])

# -----------
# System

s1 = System(techs1, Tuple{Product, Tech, Tech}[])
s2 = System(
    techs1,
    [(Product("aa"), techs1[1], techs1[2]),
     (Product("dd"), techs1[2], techs1[4])
     ]
)

println(s1)

println(s2)


# tech_list = [
#     Tech(["brown"], [], "A1", "A"),
#     Tech(["black"], ["brown"], "B1", "B"),
#     ## transport technologies
#     Tech(["brown"], ["brown"], "C1", "C"),
#     Tech(["brown"], ["brown"], "C2", "C"),
#     Tech(["yellow"], ["yellow"], "D1", "D")
# ]

# source = Tech([], ["black"], "s1", "S")

# sys = build_all_systems(source, tech_list)

# @test size(sys, 1) == 3
