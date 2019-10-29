using IRTools
import Base: push!


const VisitedVars = Dict{IRTools.Variable, TapeReference}


"""Helper type to keep the data used for recording a GraphTape at runtime."""
struct GraphRecorder
    """The partial `GraphTape` during construction."""
    tape::GraphTape
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
end

GraphRecorder(ir::IRTools.IR) = GraphRecorder(GraphTape(ir), VisitedVars())


"""
Track a `StatementNode` on the `GraphRecorder`'s tape, taking care to remember this as the current
last usage of its SSA variable.
"""
function push!(recorder::GraphRecorder, node::StatementNode)
    # push node with vars converted to tape references
    push!(recorder.tape, node)
    
    # remember mapping this nodes variable to the respective tape reference
    last_index = length(recorder.tape)
    push!(recorder.visited_vars,
          IRTools.var(node.location.line) => TapeReference(recorder.tape, last_index))
    return recorder
end

"""Track a `BranchNode` on the `GraphRecorder`'s tape."""
function push!(recorder::GraphRecorder, node::BranchNode)
    # push node with vars converted to tape references
    push!(recorder.tape, node)
    return recorder
    # branches' tape references don't need to be remembered, of course
end


record!(recorder::GraphRecorder, node::Node) = (push!(recorder, node); value(node))


@doc """
    tapeify(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
tapeify(recorder::GraphRecorder, var::IRTools.Variable) = recorder.visited_vars[var]
