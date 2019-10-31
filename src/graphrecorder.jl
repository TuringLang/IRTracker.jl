using IRTools
import Base: push!


const VisitedVars = Dict{IRTools.Variable, TapeReference}


"""Helper type to keep the data used for recording an extended Wengert list at runtime."""
struct GraphRecorder{Ctx<:AbstractTrackingContext}
    """`AbstractTrackingContext` used during tracking."""
    context::Ctx
    """(Partial) node of recorded IR statements."""
    incomplete_node::NestedCallNode
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
end

function GraphRecorder(ir::IRTools.IR, context)
    empty_node = NestedCallNode()
    empty_node.children = AbstractNode[]
    empty_node.original_ir = ir
    GraphRecorder(context, empty_node, VisitedVars())
end


function finish_recording(recorder::GraphRecorder, result, f_repr, args_repr, info)
    complete_node = recorder.incomplete_node
    complete_node.call = TapeCall(result, f_repr, collect(args_repr))
    complete_node.info = info
    return complete_node
end


"""
Track a data flow node on the `GraphRecorder`, taking care to remember this as the current last
usage of its SSA variable.
"""
function push!(recorder::GraphRecorder, node::DataflowNode)
    # push node with vars converted to tape references
    push!(recorder.incomplete_node, node)
    
    # remember mapping this nodes variable to the respective tape reference
    last_index = length(recorder.incomplete_node)
    push!(recorder.visited_vars,
          IRTools.var(location(node).line) => TapeReference(recorder.incomplete_node, last_index))
    return recorder
end

"""Track a control flow node on the `GraphRecorder`."""
function push!(recorder::GraphRecorder, node::ControlflowNode)
    # push node with vars converted to tape references
    push!(recorder.incomplete_node, node)
    return recorder
    # branches' tape references don't need to be remembered, of course
end


record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); value(node))


@doc """
    tapeify(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
tapeify(recorder::GraphRecorder, var::IRTools.Variable) = recorder.visited_vars[var]
