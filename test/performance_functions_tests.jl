
using Santiago: Range, Triangle, Trapez, Categorical
using Santiago: Pdf, Pmf, Performance

@testset "Range" begin

    @test_throws ErrorException Range(4, 3)

    d = Range(2, 4)
    @test all(extrema(d) .≈ (2, 4))
    @test minimum(d) ≈ 2
    @test maximum(d) ≈ 4

    @test d(1.8, Pdf()) ≈ 0
    @test d(1.8, Performance()) ≈ 0
    @test d(3, Pdf()) ≈ 1/2
    @test d(3, Performance()) ≈ 1


end

@testset "Triangle" begin

    @test_throws ErrorException Triangle(4, 6, 5)

    d = Triangle(1, 3, 5)
    @test all(extrema(d) .≈ (1, 5))
    @test minimum(d) ≈ 1
    @test maximum(d) ≈ 5


    @test d(0.8, Pdf()) ≈ 0
    @test d(0.8, Performance()) ≈ 0
    @test d(3, Pdf()) ≈ 1/2
    @test d(3, Performance()) ≈ 1

end


@testset "Trapez" begin

    @test_throws ErrorException Trapez(4, 5, 6, 3)

    d = Trapez(1, 2, 3, 5)
    @test all(extrema(d) .≈ (1, 5))
    @test minimum(d) ≈ 1
    @test maximum(d) ≈ 5


    @test d(0.8, Pdf()) ≈ 0
    @test d(0.8, Performance()) ≈ 0
    @test d(2.5, Pdf()) ≈ 0.4
    @test d(2.5, Performance()) ≈ 1

end

@testset "Categorical" begin
    n = ["n$i" for i in 1:4]
    v = [0.1, 0.2, 0.4, 0.3]

    @test_throws ErrorException Categorical(["n$i" for i in 1:3], v)
    @test_throws ErrorException Categorical(["n$i" for i in 1:5], v)

    d = Categorical(names=n, p=v)
    for (i, ni) in enumerate(n)
        @test d(Symbol(ni), Pdf()) == v[i]
        @test d(Symbol(ni), Pmf()) == v[i]
        @test d(Symbol(ni), Performance()) == v[i]
    end

end
