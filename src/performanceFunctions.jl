## These functions are used in the appropriateness assessment

# types to distinguish continuous and discrete functions
abstract type Continous end
abstract type Discrete end


# types to select function type
struct Pdf end
const Pmf = Pdf
struct Performance end


# --- range ---

Base.@kwdef struct Range <: Continous
    a::Float64
    b::Float64
    Range(a,b) = a > b ? error("'a' must be smaller than 'b'!") : new(a,b)
end

function (r::Range)(x, type::Pdf)
    r.a <= x < r.b ? one(x)/(r.b-r.a) : zero(x)
end

function (r::Range)(x, type::Performance)
    r.a <= x < r.b ? one(x) : zero(x)
end

Base.extrema(r::Range) = (r.a, r.b)
Base.minimum(r::Range) = r.a
Base.maximum(r::Range) = r.b


# --- Triangular ---

Base.@kwdef struct Triangle <: Continous
    a::Float64
    b::Float64
    c::Float64
    Triangle(a,b,c) = a <= b <= c ? new(a,b,c) : error("Parameters must be in order: a <= b <= c")
end

function (t::Triangle)(x, type::Pdf)
    a, b, c = t.a, t.b, t.c
    x <= a ? zero(x) :
        x <  b ? 2 * (x - a) / ((c - a) * (b - a)) :
        x == b ? 2 / (c - a) :
        x <= c ? 2 * (c - x) / ((c - a) * (c - b)) : zero(x)
end

function (t::Triangle)(x, type::Performance)
    a, c, b = t.a, t.c, t.b
    x <= a ? zero(x) :
        x <  b ? (x-a) / (b-a) :
        x == b ? one(x) :
        x <= c ? (c-x) / (c-b) : zero(x)
end

Base.extrema(t::Triangle) = (t.a, t.c)
Base.minimum(t::Triangle) = t.a
Base.maximum(t::Triangle) = t.c


# --- Trapez ---

Base.@kwdef struct Trapez <: Continous
    a::Float64
    b::Float64
    c::Float64
    d::Float64
    Trapez(a,b,c,d) = a <= b < c <= d ? new(a,b,c,d) : error("Parameters must be in order: a <= b < c <= d")
end

function (t::Trapez)(x, type::Pdf)
    a, b, c, d = t.a, t.b, t.c, t.d
    x <= a ? zero(x) :
        a <= x <  b ? 2 / (d+c-a-b) * (x-a)/(b-a) :
        b <= x <  c ? 2 / (d+c-a-b) :
        c <= x <= d ? 2 / (d+c-a-b) * (d-x)/(d-c) : zero(x)
end

function (t::Trapez)(x, type::Performance)
    a, b, c, d = t.a, t.b, t.c, t.d
    x <= a ? zero(x) :
        a <= x <  b ? (x-a)/(b-a) :
        b <= x <  c ? one(x) :
        c <= x <= d ? (d-x)/(d-c) : zero(x)
end

Base.extrema(t::Trapez) = (t.a, t.d)
Base.minimum(t::Trapez) = t.a
Base.maximum(t::Trapez) = t.d


# --- categorical ---

Base.@kwdef struct Categorical <: Discrete
    d::Dict{Symbol, Float64}
end

function Categorical(names::Array, p::Array)
    length(names) == length(p) || error("Length of 'names' and 'p' doesn't match!")
    Categorical(Dict(zip(Symbol.(names), p)))
end
Categorical(; names::Array, p::Array) = Categorical(names, p)

function (d::Categorical)(x, type::Pdf)
    d.d[x]
end

function (d::Categorical)(x, type::Performance)
    d.d[x]
end
