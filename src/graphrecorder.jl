using IRTools
import Base: push!


const VisitedVars = Dict{IRTools.Variable, TapeReference}


"""Helper type to keep the data used for recording an extended Wengert list at runtime."""
struct GraphRecorder{Ctx<:AbstractTrackingContext}
    """`AbstractTrackingContext` used during tracking."""
    context::Ctx

    """Node used as \"forward reference\" in `TapeReference`s."""
    rootnode::Union{RecursiveNode, Nothing}
    
    """IR on which the recorder is run."""
    original_ir::NullableRef{IRTools.IR}
    
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    visited_vars::VisitedVars
end

GraphRecorder(ctx::AbstractTrackingContext) = GraphRecorder(
    ctx, nothing, NullableRef{IRTools.IR}(), VisitedVars())
GraphRecorder(ctx::AbstractTrackingContext, root::RecursiveNode) = GraphRecorder(
    ctx, root, NullableRef{IRTools.IR}(), VisitedVars())


"""
Track a node on the `GraphRecorder`, taking care to remember this as the current last usage of its
SSA variable, and setting it's parent and position as a child.
"""
function push!(recorder::GraphRecorder, node::AbstractNode)
    current_position = length(recorder.rootnode.children) + 1
    node.info.position = current_position
    push!(recorder.rootnode.children, node)
    
    # remember mapping this nodes variable to the respective tape reference
    ref = TapeReference(recorder.rootnode, current_position)
    push!(recorder.visited_vars, IRTools.var(location(node).line) => ref)
    
    return recorder
end


# """Push `node` onto `recorder` and return its value."""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); value(node))

setir!(recorder::GraphRecorder, ir::IRTools.IR) = (recorder.original_ir[] = ir)


@doc """
    tapeify(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
tapeify(recorder::GraphRecorder, var::IRTools.Variable) = recorder.visited_vars[var]




