using SanitationSystemBuilder
using Base.Test

SSB = SanitationSystemBuilder

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


# # print
# println(techs2[1])
# println(techs2[2])
# println(techs2[4])

@test length(SSB.get_outputs(techs1)) == 9
@test length(SSB.get_outputs(techs2)) == 4

@test length(SSB.get_inputs(techs1)) == 9
@test length(SSB.get_inputs(techs2)) == 4

# -----------
# System

s1 = System(techs1, Tuple{Product, Tech, Tech}[])

s2 = System(
    techs2,
    [(Product("aa"), techs2[1], techs2[2]),
     (Product("bb"), techs2[2], techs2[3])
     ]
)

# complete system
s3 = System(
    techs2,
    [(Product("aa"), techs2[1], techs2[2]),
     (Product("bb"), techs2[2], techs2[3]),
     (Product("cc"), techs2[3], techs2[4]),
     (Product("dd"), techs2[3], techs2[2])
     ]
)

@test length(SSB.get_outputs(s1.techs)) == 9
@test length(SSB.get_outputs(s2.techs)) == 4
@test length(SSB.get_inputs(s1.techs)) == 9
@test length(SSB.get_inputs(s2.techs)) == 4

@test length(SSB.get_outputs(s1)) == 9
@test length(SSB.get_outputs(s2)) == 2
@test length(SSB.get_inputs(s1)) == 9
@test length(SSB.get_inputs(s2)) == 2

# complete system
@test SSB.get_outputs(s3) == Product[]
@test SSB.get_inputs(s3) == Product[]

@test SSB.is_complete(s2) == false
@test SSB.is_complete(s3) == true

# find open technologies
@test length(SSB.get_openout_techs(s2, Product("aa"))) == 0
@test length(SSB.get_openout_techs(s2, Product("cc"))) == 1
@test length(SSB.get_openout_techs(s2, Product("dd"))) == 1
@test length(SSB.get_openin_techs(s2, Product("bb"))) == 0
@test length(SSB.get_openin_techs(s2, Product("dd"))) == 1
@test length(SSB.get_openin_techs(s2, Product("cc"))) == 1

# system extension

# println( SSB.extend_system(s2, techs2[4]) )
# println( SSB.extend_system(s3, techs2[4]) )

# t1 = techs1[1]
# t2 = deepcopy(techs1)[1]
# println(Set([t1, t2]))

ss1 = build_all_systems(techs1[1], techs1)
ss2 = build_all_systems(techs2[1], techs2)

for s in ss2
    println("--- s2 ---")
    println(s)
end
