using SanitationSystemBuilder
using Base.Test


tech_list = [
             Tech(["brown"], [], "A1", "A"),
             Tech(["black"], ["brown"], "B1", "B"),
             ## transport technologies
             Tech(["brown"], ["brown"], "C1", "C"),
             Tech(["brown"], ["brown"], "C2", "C"),
             Tech(["yellow"], ["yellow"], "D1", "D")
             ]

source = Tech([], ["black"], "s1", "S")

sys = build_all_systems(source, tech_list)

@test size(sys, 1) == 3
