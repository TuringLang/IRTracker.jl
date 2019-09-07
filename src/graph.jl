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
abstract type StatementNode <: Node end
abstract type BranchNode <: Node end


"""Record of data and control flow of evaluating IR."""
struct GraphTape
    nodes::Vector{<:Node}
end

GraphTape() = GraphTape(Node[])
push!(tape::GraphTape, node::Node) = (push!(tape.nodes, node); tape)


struct Constant <: StatementNode
    value::Any
    index::StmtIndex
    info::StatementInfo
end

Constant(value, index) = Constant(value, index, StatementInfo())


struct PrimitiveCall <: StatementNode
    expr::Any
    value::Any
    index::StmtIndex
    info::StatementInfo
end

PrimitiveCall(expr, value, index) = PrimitiveCall(expr, value, index, StatementInfo())


struct NestedCall <: StatementNode
    expr::Any
    value::Any
    index::StmtIndex
    subtape::GraphTape
    info::StatementInfo
end

NestedCall(expr, value, index, subtape = GraphTape()) =
    NestedCall(expr, value, index, subtape, StatementInfo())
push!(node::NestedCall, child::Node) = (push!(node.subtape, child); node)


struct SpecialStatement <: StatementNode
    expr::Any
    value::Any
    index::StmtIndex
    info::StatementInfo
end

SpecialStatement(expr, value, index) = SpecialStatement(expr, value, index, StatementInfo())


struct Argument <: StatementNode
    value::Any
    index::StmtIndex
    info::StatementInfo
end

Argument(value, index) = Argument(value, index, StatementInfo())


struct Return <: BranchNode
    expr::Any
    value::Any
    index::BranchIndex
    info::StatementInfo
end

Return(expr, value, index) = Return(expr, value, index, StatementInfo())

struct Branch <: BranchNode
    target::Int
    arg_exprs::Vector{Any}
    arg_values::Vector{Any}
    condition_expr::Any
    index::BranchIndex
    info::StatementInfo
end

Branch(target, arg_exprs, arg_values, condition_expr, index) =
    Branch(target, arg_exprs, arg_values, condition_expr, index, StatementInfo())



value(node::StatementNode) = node.value
value(node::BranchNode) = nothing
