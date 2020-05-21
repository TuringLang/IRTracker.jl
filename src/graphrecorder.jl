using IRTools
import Base: push!


const VariableUsages = Dict{IRTools.Variable, Int}


"""
    GraphRecorder{Ctx<:AbstractTrackingContext}(ctx::Ctx)

Helper type to keep the runtime data used for tracking an extended Wengert list, with tracking
context `Ctx`.
"""
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
    push!(recorder, node)

Track a node on the `GraphRecorder`, taking care to remember this as the current last usage of its
SSA variable, and setting it's parent and position as a child.
"""
function push!(recorder::GraphRecorder, node::AbstractNode)
    current_position = length(recorder.children) + 1
    setposition!(node.info, current_position)
    push!(recorder.children, node)
    record_variable_usage!(recorder, node, current_position)
    return recorder
end


"""
    record_variable_usage!(recorder, node, current_position)

Remember the last usage of the SSA variable represented by node in the tracked IR.  This is
necessary since in loops, the same SSA statement can be run, and thus tracked, multiple times,
and we want the `TapeReference`s to point only at the recorded node of the last usage.
"""
function record_variable_usage!(recorder::GraphRecorder, node::DataFlowNode, current_position::Int)
    current_var = IRTools.var(getlocation(node).line)
    recorder.variable_usages[current_var] = current_position
    return recorder
end

record_variable_usage!(recorder::GraphRecorder, ::ControlFlowNode, ::Int) = recorder


"""
    record!(recorder, node)

Push `node` onto `recorder` and return its value.
"""
record!(recorder::GraphRecorder, node::AbstractNode) = (push!(recorder, node); getvalue_ref(node))


"""
    saveir!(recorder, ir)

Save the original IR of the function tracked by `recorder`.  This is not done in the constructor
since the `recorder` is set up outside the recording function call, at which time the IR data is 
not yet available.
"""
saveir!(recorder::GraphRecorder, ir::IRTools.IR) = (recorder.original_ir = ir)

"""
    finalize!(recorder, result, f_repr, args_repr, info)

Construct a `NestedCallNode` from the data recorded in `recorder`, given the information about what
function call it resulted from.  Only at this point, the parent of the child nodes can be set to the
final node.
"""
function finalize!(recorder::GraphRecorder, result::T, f_repr::TapeExpr,
                   args_repr::ArgumentTuple{TapeExpr}, info) where {T}
    f = getvalue_ref(f_repr)
    args_repr, varargs_repr = split_varargs(f, args_repr)
    call = TapeCall(result, f_repr, args_repr, varargs_repr)
    node = NestedCallNode(call, recorder.children, info)
    recorder.rootnode[] = node  # set the parent node of all recorded children
    return node
end


"""
    trackedvariable(recorder, var, value)

Convert SSA reference in `var` to the `TapeReference` where `var` has been used last.
"""
function trackedvariable(recorder::GraphRecorder, var::IRTools.Variable, value::T) where {T}
    position = recorder.variable_usages[var]
    node = recorder.children[position]
    return TapeReference(value, node, position)
end




_inferred_params(signature::UnionAll) = _inferred_params(signature.body)
_inferred_params(signature) = signature.parameters


"""
    split_varargs(f, args_repr)

Given function `f`, and argument expression tuple `args_repr`, split the tuple into the "normal" and
the "varargs" part (by reflecting on the dispatched method).
"""
function split_varargs(@nospecialize(f), args_repr::ArgumentTuple{TapeValue})
    arguments = getvalue_ref.(args_repr)
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

@generated function split_varargs(f::Core.Builtin, args_repr::ArgumentTuple{TapeValue})
    return :(args_repr, ())
end
