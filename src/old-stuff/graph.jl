# struct Call{F, As<:Tuple}
#     func::F
#     args::As
# end

# Call(f::F, args::T) where {F, T} = Call{F, T}(f, args)
# Call() = Call(nothing, ())

# # When deserialising, the object_id changes
# Base.:(==)(a::Call, b::Call) = a.func == b.func && a.args == b.args

# @inline (c::Call)() = c.func(data.(c.args)...)

export Graph,
    PrimValue,
    Call,
    Variable,
    Constant,
    PrimitiveCall

abstract type Graph end
abstract type Primitive <: Graph end
abstract type Call <: Graph end

struct Variable <: Primitive
    name::Symbol
    value::Any
end

Variable(name, value) = Variable(name, value, nothing)

struct Constant <: Primitive
    value::Any
end

struct PrimitiveCall <: Call
    name::Symbol
    args::Vector{<:PrimValue}
    result::Variable
end

struct NestedCall <: Call
    name::Symbol
    args::Vector{<:PrimValue}
    subgraph::Graph
end

# plus = PrimitiveCall(:+, [Variable(:_2, 1), Constant(1)], 2)

value(v::Variable) = v.value
value(c::Constant) = v.value
value(c::PrimitiveCall) = c.result
value(c::NestedCall) = value(c.subgraph)

# abstract type Call end

# struct PrimitiveCall <: Call
#     name::Symbol
#     args::Vector{PrimValue}
# end

# struct NestedCall <: Call
#     name::Symbol
#     args::Vector{PrimValue}
#     graph::Graph
# end

# struct Statement
#     id::Id
#     call::Call
#     # metadata::Any
# end

# struct Branch


