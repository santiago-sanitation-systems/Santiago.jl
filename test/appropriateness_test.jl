
using Santiago: Range, Triangle, Trapez, Categorical
using Santiago: Pdf, Pmf, Performance

# ---------------------------------
# Performance functions

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
    dd = Dict(Symbol("n$i") => rand() for i in 1:5)
    d = Categorical(dd)
    for (k, v) in dd
        @test d(k, Pdf()) == v
        @test d(k, Pmf()) == v
        @test d(k, Performance()) == v
    end

end

# ---------------------------------
# Appropriateness

@testset "Categorical" begin
    att = Dict(:type => "Performance",
               :function => "Categorical",
               :parameters => Dict("a" => 0.7, "b" =>  0.3, "c" => 1)
               )

    att[:parameters]["a"] = -0.1
    @test_throws ErrorException SSB.get_distribution(att)

    att[:parameters]["a"] = 1.1
    @test_throws ErrorException SSB.get_distribution(att)


    att = Dict(:type => "Pdf",
               :function => "Categorical",
               :parameters => Dict("a" => 0.1, "b" =>  0.3, "c" => 0.6)
               )
    att[:parameters]["a"] = 0.2
    @test_throws ErrorException SSB.get_distribution(att)
    att[:parameters]["a"] = 0.01
    @test_throws ErrorException SSB.get_distribution(att)
end


@testset "Range" begin
    att = Dict(:type => "Pdf",
               :function => "Range",
               :parameters => Dict("b" => 3.2, "a" => 3)
               )
    d, t = SSB.get_distribution(att)
    @test d == Range(3.0, 3.2)
    @test t == Pdf()
    att[:parameters]["useless"] = 0.2
    @test_throws MethodError SSB.get_distribution(att)
end

@testset "Triangle" begin
    att = Dict(:type => "Pdf",
               :function => "Triangle",
               :parameters => Dict("b" => 3.2, "a" => 3, "c" => 4)
               )
    d, t = SSB.get_distribution(att)
    @test d == Triangle(3.0, 3.2, 4)
    @test t == Pdf()
    att[:parameters]["useless"] = 0.2
    @test_throws MethodError SSB.get_distribution(att)
end

@testset "Trapez" begin
    att = Dict(:type => "Pdf",
               :function => "Trapez",
               :parameters => Dict("b" => 3.2, "a" => 3, "c" => 4, "d" => 6)
               )
    d, t = SSB.get_distribution(att)
    @test d == Trapez(3.0, 3.2, 4, 6)
    @test t == Pdf()
    att[:parameters]["useless"] = 0.2
    @test_throws MethodError SSB.get_distribution(att)
end
