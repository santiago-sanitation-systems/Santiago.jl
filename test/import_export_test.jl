## -------------------------------------------------------
## import / export functions



# -----------
# Conversion of NamedArrays into nested Dicts

using NamedArrays

# - 1d
na = NamedArray(rand(3))
setnames!(na, ["a$i" for i in 1:3], 1)
dd = Dict(na)

for j in 1:3
    @test na["a$j"] == dd["a$j"]
end

# - 3d
na = NamedArray(rand(3,4,5))
setnames!(na, ["a$i" for i in 1:3], 1)
setnames!(na, ["b$i" for i in 1:4], 2)
setnames!(na, ["c$i" for i in 1:5], 3)
dd = Dict(na)

@test na["a1", "b1", "c1"] == dd["a1"]["b1"]["c1"]
@test na["a3", "b4", "c5"] == dd["a3"]["b4"]["c5"]
@test na["a1", "b2", "c3"] == dd["a1"]["b2"]["c3"]
