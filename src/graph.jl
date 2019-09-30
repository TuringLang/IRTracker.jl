using IRTools
import Base: push!, show


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



"""Record a node on a graph tape."""
record!(tape::GraphTape, node::Node) = (push!(tape, node); value(node))

@generated function record!(tape::GraphTape, index::VarIndex, expr, f::F, args...) where F
    # TODO: check this out:
    # @nospecialize args
    
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    mod = Base.typename(F).module
    is_builtin = ((F <: Core.Builtin) && !(mod === Core.Compiler)) || F <: Core.IntrinsicFunction
    
    if is_builtin 
        quote
            result = f(args...)
            call = PrimitiveCall(expr, result, index)
            push!(tape, call)
            return result
        end
    else
        quote
            result, graph = track(f, args...)
            call = NestedCall(expr, result, index, graph)
            push!(tape, call)
            return result
        end
    end
end

