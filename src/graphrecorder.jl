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



function finalize!(recorder::GraphRecorder, result, f_repr, args_repr, info)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    ax, vx = _split_va(f, args)

    if isnothing(vx)
        call = TapeCall(result, f_repr, args_repr[ax])
    else
        call = TapeCall(result, f_repr, args_repr[ax], args_repr[vx])
    end
    
    node = NestedCallNode(call, recorder.children, info)
    recorder.rootnode[] = node  # set the parent node of all recorded children
    return node
end


@doc """
    trackedvariable(recorder, var)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
trackedvariable(recorder::GraphRecorder, var::IRTools.Variable) = recorder.variable_usages[var]




_inferred_params(signature::UnionAll) = _inferred_params(signature.body)
_inferred_params(signature) = signature.parameters

_split_va(@nospecialize(f::Core.Builtin), @nospecialize(arguments)) =
    eachindex(arguments), nothing

function _split_va(@nospecialize(f), @nospecialize(arguments))
    ArgTypes = Tuple{Core.Typeof.(arguments)...}
    m = which(f, ArgTypes)
    L = length(arguments)
    
    if m.isva
        inferred_parameters = _inferred_params(m.sig)
        I = length(inferred_parameters) - 1 # remove self parameter
        return 1:(I - 1), I:L
    else
        return 1:L, nothing
    end
end
