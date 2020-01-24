using IRTools
import Base: push!


const VariableUsages = Dict{IRTools.Variable, TapeReference}


"""Helper type to keep the data used for recording an extended Wengert list at runtime."""
mutable struct GraphRecorder{Ctx<:AbstractTrackingContext}
    """`AbstractTrackingContext` used during tracking."""
    context::Ctx

    """Recorded child nodes."""
    children::Vector{AbstractNode}
    
    """IR on which the recorder is run."""
    original_ir::Union{IRTools.IR, Nothing}
    
    """
    The mapping from original SSA variables to `TapeReference`es, used for substituting them
    in the recorded expressions.
    """
    variable_usages::VariableUsages

    """Reference to be filled later with the node resulting from this recording."""
    rootnode::NullableRef{RecursiveNode}
end

GraphRecorder(ctx::AbstractTrackingContext) = GraphRecorder(
    ctx, Vector{AbstractNode}(), nothing, VariableUsages(), NullableRef{RecursiveNode}())


"""
Track a node on the `GraphRecorder`, taking care to remember this as the current last usage of its
SSA variable, and setting it's parent and position as a child.
"""
function push!(recorder::GraphRecorder, node::AbstractNode)
    current_position = length(recorder.children) + 1
    setposition!(node.info, current_position)
    push!(recorder.children, node)
    
    # remember mapping this nodes variable to be mentioned last at the current position
    record_variable_usage!(recorder, node, current_position)
    return recorder
end

function record_variable_usage!(recorder::GraphRecorder, node::DataFlowNode, current_position::Int)
    current_reference = TapeReference(node, current_position)
    current_var = IRTools.var(getlocation(node).line)
    recorder.variable_usages[current_var] = current_reference
    return recorder
end

record_variable_usage!(recorder::GraphRecorder, ::ControlFlowNode, ::Int) = recorder


# """Push `node` onto `recorder` and return its value."""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); getvalue(node))

saveir!(recorder::GraphRecorder, ir::IRTools.IR) = (recorder.original_ir = ir)


@doc """
    trackedvariable(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
trackedvariable(recorder::GraphRecorder, var::IRTools.Variable) = recorder.variable_usages[var]




