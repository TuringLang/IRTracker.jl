import Base: push!


const VisitedVars = Dict{IRTools.Variable, TapeReference}


struct GraphRecorder
    tape::GraphTape
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
end

GraphRecorder(ir::IRTools.IR) = GraphRecorder(GraphTape(ir), VisitedVars())


function push!(recorder::GraphRecorder, node::StatementNode)
    # push node with vars converted to tape indices
    tapeified_node = tapeify_vars(recorder.visited_vars, node)
    push!(recorder.tape, tapeified_node)
    
    # record this node as a new tape index
    last_index = length(recorder.tape)
    push!(recorder.visited_vars,
          IRTools.var(node.index.id) => TapeReference(recorder.tape, last_index))
    return recorder
end

function push!(recorder::GraphRecorder, node::BranchNode)
    # push node with vars converted to tape indices
    tapeified_node = tapeify_vars(recorder.visited_vars, node)
    push!(recorder.tape, tapeified_node)
    return recorder
    # branches' indices don't need to be recorded, of course
end



@doc """
    tapeify_vars(visited_vars, node)

Convert SSA references in expressions in `node` to `TapeReference`es, based on the tape positions
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
