using IRTools
using Core.Compiler: LineInfoNode

import Base: push!, show


export StatementInfo

"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)

show(io::IO, si::StatementInfo) =
    print(io, "StatementInfo(", si === nothing ? "" : si.metadata,")")





export Argument,
    # ConditionalBranch,
    Branch,
    GraphTape,
    NestedCall,
    Node,
    PrimitiveCall,
    Return
    # UnconditionalBranch

abstract type Node end

"""Record of data and control flow of evaluating IR."""
struct GraphTape
    nodes::Vector{<:Node}
end

GraphTape() = GraphTape(Node[])
push!(tape::GraphTape, node::Node) = push!(tape.nodes, node)


struct Constant <: Node
    value::Any
    info::StatementInfo
end

Constant(value) = Constant(value, StatementInfo())


struct PrimitiveCall <: Node
    expr::Any
    value::Any
    info::StatementInfo
end

PrimitiveCall(expr, value) = PrimitiveCall(expr, value, StatementInfo())


struct NestedCall <: Node
    expr::Any
    value::Any
    subtape::GraphTape
    info::StatementInfo
end

NestedCall(expr, value, subtape = GraphTape()) = NestedCall(expr, value, subtape, StatementInfo())
push!(node::NestedCall, child::Node) = (push!(node.subtape, child); node)


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




# v = Node[]
# push!(v, Argument(2, "hi", StatementInfo()))
# push!(v, PrimitiveCall(:rand, [], 0.4534, StatementInfo()))
# push!(v, PrimitiveCall(:Foo, [IndexRef(2)], "sdf", StatementInfo()))

