using IRTools
import Base: push!


const VisitedVars = Dict{IRTools.Variable, TapeReference}


"""Helper type to keep the data used for recording an extended Wengert list at runtime."""
struct GraphRecorder{Ctx<:AbstractTrackingContext}
    """`AbstractTrackingContext` used during tracking."""
    context::Ctx
    
    """(Partial) list of recorded IR statements."""
    tape::Vector{AbstractNode}
    
    """IR on which the recorder is run."""
    original_ir::IRTools.IR
    
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
    
    """Node used as \"forward reference\" in `TapeReference`s."""
    incomplete_node::NestedCallNode
end

GraphRecorder(ir::IRTools.IR, context) =
    GraphRecorder(context, AbstractNode[], ir, VisitedVars(), NestedCallNode())


"""Wrap the list of recorded nodes of `recorder` into a full `NestedCallNode`."""
function finish_recording(recorder::GraphRecorder, result, f_repr, args_repr, info)
    call = TapeCall(result, f_repr, args_repr)
    complete_node = recorder.incomplete_node
    complete_node.call = call
    complete_node.children = recorder.tape
    complete_node.original_ir = recorder.original_ir
    complete_node.info = info
    calculate_descendants!(complete_node)
    return complete_node
end


"""
Track a data flow node on the `GraphRecorder`, taking care to remember this as the current last
usage of its SSA variable.
"""
function push!(recorder::GraphRecorder, node::DataFlowNode)
    # push node with vars converted to tape references
    push!(recorder.tape, node)
    
    # remember mapping this nodes variable to the respective tape reference
    last_index = length(recorder.tape)
    push!(recorder.visited_vars,
          IRTools.var(location(node).line) => TapeReference(recorder.incomplete_node, last_index))
    return recorder
end

"""Track a control flow node on the `GraphRecorder`."""
function push!(recorder::GraphRecorder, node::ControlFlowNode)
    # push node with vars converted to tape references
    push!(recorder.tape, node)
    return recorder
    # branches' tape references don't need to be remembered, of course
end


"""Push `node` onto `recorder` and return its value."""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); value(node))


@doc """
    tapeify(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
tapeify(recorder::GraphRecorder, var::IRTools.Variable) = recorder.visited_vars[var]
