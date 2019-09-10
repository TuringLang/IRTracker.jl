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


const VisitedVars = Dict{IRTools.Variable, TapeIndex}

"""Record of data and control flow of evaluating IR."""
struct GraphTape
    ir::IRTools.IR
    nodes::Vector{<:Node}
    visited_vars::VisitedVars
end

GraphTape(ir::IRTools.IR) = GraphTape(ir, Node[], VisitedVars())



struct Argument <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Argument(value, index) = Argument(value, index, StatementInfo())


struct Constant <: StatementNode
    value::Any
    index::VarIndex
    info::StatementInfo
end

Constant(value, index) = Constant(value, index, StatementInfo())


struct PrimitiveCall <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    info::StatementInfo
end

PrimitiveCall(expr, value, index) = PrimitiveCall(expr, value, index, StatementInfo())


struct NestedCall <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    subtape::GraphTape
    info::StatementInfo
end

NestedCall(expr, value, index, subtape = GraphTape()) =
    NestedCall(expr, value, index, subtape, StatementInfo())

push!(node::NestedCall, child::Node) = (push!(node.subtape, child); node)


struct SpecialStatement <: StatementNode
    expr::Any
    value::Any
    index::VarIndex
    info::StatementInfo
end

SpecialStatement(expr, value, index) = SpecialStatement(expr, value, index, StatementInfo())


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




tapeify_vars(visited_vars::VisitedVars) = expr -> tapeify_vars(visited_vars, expr)
tapeify_vars(visited_vars::VisitedVars, expr::Expr) =
    Expr(expr.head, map(tapeify_vars(visited_vars), expr.args)...)
tapeify_vars(visited_vars::VisitedVars, expr) = get(visited_vars, expr, expr)
tapeify_vars(visited_vars::VisitedVars, node::PrimitiveCall) =
    PrimitiveCall(tapeify_vars(visited_vars, node.expr), node.value, node.index, node.info)
tapeify_vars(visited_vars::VisitedVars, node::StatementNode) =
    NestedCall(tapeify_vars(visited_vars, node.expr), node.value, node.index,
               node.subtape, node.info)
tapeify_vars(visited_vars::VisitedVars, node::SpecialStatement) =
    SpecialStatement(tapeify_vars(visited_vars, node.expr), node.value, node.index, node.info)
tapeify_vars(visited_vars::VisitedVars, node::Return) =
    Return(tapeify_vars(visited_vars, node.expr), node.value, node.index, node.info)
function tapeify_vars(visited_vars::VisitedVars, node::Branch)
    tapeified_arg_exprs =
        isnothing(node.arg_exprs) ? nothing : map(tapeify_vars(visited_vars), node.arg_exprs)
    Branch(node.target, tapeified_arg_exprs, node.arg_values,
           tapeify_vars(visited_vars, node.condition_expr), node.index, node.info)
end



function push!(tape::GraphTape, node::Union{Argument, Constant})
    push!(tape.nodes, node)
    
    # record this node as a new tape index
    last_index = length(tape.nodes)
    push!(tape.visited_vars, IRTools.var(node.index.id) => TapeIndex(last_index))
    
    return tape
end

function push!(tape::GraphTape, node::Union{PrimitiveCall, NestedCall, SpecialStatement})
    # push node with vars converted to tape indices
    tapeified_node = tapeify_vars(tape.visited_vars, node)
    push!(tape.nodes, tapeified_node)

    # record this node as a new tape index
    last_index = length(tape.nodes)
    push!(tape.visited_vars, IRTools.var(node.index.id) => TapeIndex(last_index))
    return tape
end

function push!(tape::GraphTape, node::Union{Return, Branch})
    # push node with vars converted to tape indices
    tapeified_node = tapeify_vars(tape.visited_vars, node)
    push!(tape.nodes, tapeified_node)
    return tape
end
