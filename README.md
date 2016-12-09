# SanitationSystemBuilder


Finds all combination of technologies that result in a valid
sanitation system.


# Installation

SanitationSystemBuilder can then be installed with the Julia command`
Pkg.clone()`:
```Julia
Pkg.clone("https://gitlab.com/scheidan/SanitationSystemBuilder.jl.git")
```

# Usage

```Julia
using SanitationSystemBuilder
# -----------
#  define technologies
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

# -----------
# find all systems


systems1 = build_all_systems(techs1[1], techs1)

# write pdfs
for i in 1:length(systems1)
    writedotfile(systems1[i], "temp.dot")
    run(`dot -Tpdf temp.dot -o systems1_$i.pdf`)
end


systems2 = build_all_systems(techs2[1], techs2)

# write pdfs
for i in 1:length(systems2)
    writedotfile(systems2[i], "temp.dot")
    run(`dot -Tpdf temp.dot -o systems2_$i.pdf`)
end


```
