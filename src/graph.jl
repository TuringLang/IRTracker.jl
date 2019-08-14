using IRTools
using Core.Compiler: LineInfoNode

import Base: show


export StatementInfo

"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)

show(io::IO, si::StatementInfo) =
    print(io, "StatementInfo(", si === nothing ? "" : si.metadata,")")



export IndexRef

"""Reference to another SSA value."""
struct IndexRef
    index::Int
end

show(io::IO, r::IndexRef) = print(io, "[$(r.index)]")



export Argument,
    # ConditionalBranch,
    Branch,
    NestedCall,
    Node,
    PrimitiveCall,
    Return
    # UnconditionalBranch

abstract type Node end

# hack for https://github.com/JuliaLang/julia/issues/269 (recursive type declarations)
abstract type AbstractGraphTape end


struct PrimitiveCall <: Node
    expr::Any
    value::Any
    info::StatementInfo
end

PrimitiveCall(expr, value) = PrimitiveCall(expr, value, StatementInfo())


struct NestedCall <: Node
    expr::Any
    value::Any
    inner::AbstractGraphTape
    info::StatementInfo
end

NestedCall(expr, value, children) = NestedCall(expr, value, children, StatementInfo())


struct Argument <: Node
    number::Int
    value::Any
    info::StatementInfo
end

Argument(number, value) = Argument(number, value, StatementInfo())


struct Return <: Node
    expr::Any
    value::Any
    info::StatementInfo
end

Return(expr, value) = Return(expr, value, StatementInfo())

struct Branch
    target::Int
    args::Vector{Int}
    info::StatementInfo
end

Branch(target, args) = Branch(target, args, StatementInfo())

# struct UnconditionalBranch
#     target::Int
#     args::Vector{Int}
#     info::StatementInfo
# end

# struct ConditionalBranch
#     target::Int
#     args::Vector{<:IndexValue}
#     condition::IndexValue
#     info::StatementInfo
# end


function show(io::IO, node::PrimitiveCall, level = 0)
    print(io, " " ^ 2level)
    print(io, node.expr, " = ", node.value)
end

function show(io::IO, node::NestedCall, level = 0)
    print(io, " " ^ 2level)
    print(io, node.expr, " = ", node.value, "\n")
    for child in node.children
        show(io, child, level + 1)
    end
end

function show(io::IO, node::Argument, level = 0)
    print(io, " " ^ 2level)
    print(io, "Argument ", node.number, " = ", node.value)
end

function show(io::IO, node::Return, level = 0)
    print(io, " " ^ 2level)
    print(io, "return ", node.value)
end

function show(io::IO, node::Branch, level = 0)
    print(io, " " ^ 2level)
    print(io, "br ", node.target)
end

# function show(io::IO, node::UnconditionalBranch, level = 0)
#     print(io, " " ^ 2level)
#     print(io, "br ", node.target, " (", join(node.args, ", "), ")")
# end

# function show(io::IO, node::UnconditionalBranch, level = 0)
#     print(io, " " ^ 2level)
#     print(io, "br ", node.target, " (", join(node.args, ", "), ") unless ", node.condition)
# end


# v = Node[]
# push!(v, Argument(2, "hi", StatementInfo()))
# push!(v, PrimitiveCall(:rand, [], 0.4534, StatementInfo()))
# push!(v, PrimitiveCall(:Foo, [IndexRef(2)], "sdf", StatementInfo()))

