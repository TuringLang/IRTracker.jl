using IRTools
import Base: push!


const VariableUsages = Dict{IRTools.Variable, Int}


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
    current_var = IRTools.var(getlocation(node).line)
    recorder.variable_usages[current_var] = current_position
    return recorder
end

record_variable_usage!(recorder::GraphRecorder, ::ControlFlowNode, ::Int) = recorder


# """Push `node` onto `recorder` and return its value."""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); getvalue(node))

saveir!(recorder::GraphRecorder, ir::IRTools.IR) = (recorder.original_ir = ir)



function finalize!(recorder::GraphRecorder, result::T, f_repr::TapeExpr,
                   args_repr::ArgumentTuple{TapeExpr}, info) where {T}
    f = getvalue(f_repr)
    args_repr, varargs_repr = split_varargs(f, args_repr)
    call = TapeCall{T}(result, f_repr, args_repr, varargs_repr)
    node = NestedCallNode{T}(call, recorder.children, info)
    recorder.rootnode[] = node  # set the parent node of all recorded children
    return node
end


@doc """
    trackedvariable(recorder, var, value)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
function trackedvariable(recorder::GraphRecorder, var::IRTools.Variable, value::T) where {T}
    position = recorder.variable_usages[var]
    node = recorder.children[position]::DataFlowNode{T}
    return TapeReference(node, position)
end




_inferred_params(signature::UnionAll) = _inferred_params(signature.body)
_inferred_params(signature) = signature.parameters

split_varargs(f::Core.Builtin, args_repr::ArgumentTuple{TapeExpr}) = args_repr, ()

function split_varargs(@nospecialize(f), args_repr::ArgumentTuple{TapeExpr})
    arguments = getvalue.(args_repr)
    ArgTypes = Tuple{Core.Typeof.(arguments)...}
    m = which(f, ArgTypes)
    L = length(arguments)
    
    if m.isva
        inferred_parameters = _inferred_params(m.sig)
        I = length(inferred_parameters) - 1 # remove self parameter
        return args_repr[1:(I - 1)], args_repr[I:L]
    else
        return args_repr, ()
    end
end
