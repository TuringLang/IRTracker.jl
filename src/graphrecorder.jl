using IRTools
import Base: push!


const VariableUsages = Dict{IRTools.Variable, TapeReference}


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
    variable_usages::VariableUsages
end

GraphRecorder(ctx::AbstractTrackingContext) = GraphRecorder(
    ctx, nothing, NullableRef{IRTools.IR}(), VariableUsages())
GraphRecorder(ctx::AbstractTrackingContext, root::RecursiveNode) = GraphRecorder(
    ctx, root, NullableRef{IRTools.IR}(), VariableUsages())


"""
Track a node on the `GraphRecorder`, taking care to remember this as the current last usage of its
SSA variable, and setting it's parent and position as a child.
"""
function push!(recorder::GraphRecorder, node::AbstractNode)
    current_position = length(recorder.rootnode.children) + 1
    node.info.position = current_position
    push!(recorder.rootnode.children, node)
    
    # remember mapping this nodes variable to be mentioned last at the current position
    record_variable_usage!(recorder, node, current_position)
    return recorder
end

function record_variable_usage!(recorder::GraphRecorder, node::DataFlowNode, current_position::Int)
    current_reference = TapeReference(recorder.rootnode, current_position)
    current_var = IRTools.var(location(node).line)
    recorder.variable_usages[current_var] = current_reference
    return recorder
end

record_variable_usage!(recorder::GraphRecorder, ::ControlFlowNode, ::Int) = recorder


# """Push `node` onto `recorder` and return its value."""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); value(node))

saveir!(recorder::GraphRecorder, ir::IRTools.IR) = (recorder.original_ir[] = ir)


@doc """
    trackedvariable(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
trackedvariable(recorder::GraphRecorder, var::IRTools.Variable) = recorder.variable_usages[var]




