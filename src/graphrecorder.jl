using IRTools
import Base: push!


const VisitedVars = Dict{IRTools.Variable, TapeReference}


"""Helper type to keep the data used for recording an extended Wengert list at runtime."""
struct GraphRecorder{Ctx<:AbstractTrackingContext}
    """`AbstractTrackingContext` used during tracking."""
    context::Ctx
    
    """IR on which the recorder is run."""
    original_ir::IRTools.IR
    
    """(Partial) list of recorded IR statements."""
    tape::Vector{AbstractNode}
    
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
    
    """Node used as \"forward reference\" in `TapeReference`s."""
    rootnode_ref::ParentRef
end

GraphRecorder(ctx::AbstractTrackingContext, ir::IRTools.IR) = GraphRecorder(
    ctx, ir, AbstractNode[], VisitedVars(), no_parent)


"""Wrap the list of recorded nodes of `recorder` into a full `NestedCallNode`."""
function finish_recording(recorder::GraphRecorder, result, f_repr, args_repr, info)
    call = TapeCall(result, f_repr, args_repr)
    recorder.rootnode_ref[] = NestedCallNode(call, recorder.tape, recorder.original_ir, info)
    return recorder.rootnode_ref[]
end


"""
Track a node on the `GraphRecorder`, taking care to remember this as the current last usage of its
SSA variable, and setting it's parent and position as a child.
"""
function push!(recorder::GraphRecorder, node::AbstractNode)
    current_position = length(recorder.tape)    
    node.info.position = current_position
    node.info.parent_ref = recorder.rootnode_ref
    push!(recorder.tape, node)
    
    # remember mapping this nodes variable to the respective tape reference
    ref = TapeReference(recorder.rootnode_ref, current_position)
    push!(recorder.visited_vars, IRTools.var(location(node).line) => ref)
    
    return recorder
end


"""Push `node` onto `recorder` and return its value."""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); value(node))


@doc """
    tapeify(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
tapeify(recorder::GraphRecorder, var::IRTools.Variable) = recorder.visited_vars[var]
