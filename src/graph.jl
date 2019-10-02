using IRTools
import Base: push!, show
import Base: collect, eltype, iterate, length, size
import Base: firstindex, getindex, lastindex


"""Extra data and metadata associated with an SSA statement"""
struct StatementInfo
    # line::LineInfoNode
    metadata::Any
end

StatementInfo() = StatementInfo(nothing)

show(io::IO, si::StatementInfo) =
    print(io, "StatementInfo(", si === nothing ? "" : si.metadata,")")



abstract type Node end
abstract type StatementNode <: Node end
abstract type BranchNode <: Node end


"""Index to a node of a `GraphTape`s node list; like the indices of a Wengert list."""
struct TapeIndex
    id::Int
end


const VisitedVars = Dict{IRTools.Variable, TapeIndex}


"""
Record of data and control flow of evaluated IR.  Essentially, a list of 
(potentially nested) `Node`s.
"""
struct GraphTape
    """The methods original IR, to which the `IRIndex`es in `nodes` refer to."""
    original_ir::IRTools.IR
    """Vector of recorded IR statements, as nodes in the computation graph (like in a Wengert list)"""
    nodes::Vector{<:Node}
    """
    The mapping from original SSA variables to `TapeIndex`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
end

GraphTape(ir::IRTools.IR) = GraphTape(ir, Node[], VisitedVars())

function push!(tape::GraphTape, node::StatementNode)
    # push node with vars converted to tape indices
    tapeified_node = tapeify_vars(tape.visited_vars, node)
    push!(tape.nodes, tapeified_node)

    # record this node as a new tape index
    last_index = length(tape.nodes)
    push!(tape.visited_vars, IRTools.var(node.index.id) => TapeIndex(last_index))
    return tape
end

function push!(tape::GraphTape, node::BranchNode)
    # push node with vars converted to tape indices
    tapeified_node = tapeify_vars(tape.visited_vars, node)
    push!(tape.nodes, tapeified_node)
    return tape
    # branches' indices don't need to be recorded, of course
end


iterate(tape::GraphTape) = iterate(tape.nodes)
iterate(tape::GraphTape, state) = iterate(tape.nodes, state)
eltype(tape::GraphTape) = Node
length(tape::GraphTape) = length(tape.nodes)
size(tape::GraphTape) = size(tape.nodes)
collect(tape::GraphTape) = collect(tape.nodes)
iterate(rTape::Iterators.Reverse{GraphTape}) = iterate(Iterators.reverse(rTape.itr.nodes))
iterate(rTape::Iterators.Reverse{GraphTape}, state) = iterate(Iterators.reverse(rTape.itr.nodes), state)

getindex(tape::GraphTape, i) = tape.nodes[i]
getindex(tape::GraphTape, ix::TapeIndex) = tape[ix.id]
firstindex(tape::GraphTape) = firstindex(tape.nodes)
lastindex(tape::GraphTape) = lastindex(tape.nodes)


function backward(f!, tape::GraphTape)
    for node in Iterators.reverse(tape)
        f!(node, parents(tape, node))
    end
end


include("nodes.jl")


@doc """
    tapeify_vars(visited_vars, node)

Convert SSA references in expressions in `node` to `TapeIndex`es, based on the tape positions
of the current tape.
""" tapeify_vars

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
tapeify_vars(visited_vars::VisitedVars, node::Argument) = node
tapeify_vars(visited_vars::VisitedVars, node::Constant) = node
tapeify_vars(visited_vars::VisitedVars, node::Return) =
    Return(tapeify_vars(visited_vars, node.expr), node.value, node.index, node.info)
function tapeify_vars(visited_vars::VisitedVars, node::Branch)
    tapeified_arg_exprs =
        isnothing(node.arg_exprs) ? nothing : map(tapeify_vars(visited_vars), node.arg_exprs)
    Branch(node.target, tapeified_arg_exprs, node.arg_values,
           tapeify_vars(visited_vars, node.condition_expr), node.index, node.info)
end
