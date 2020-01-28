using IRTools
using IRTools: IR, @dynamo



"""Construct the transformed IR with tracking statements from `old_ir`."""
function transform_ir(old_ir::IR)
    IRTools.explicitbranch!(old_ir) # make implicit jumps explicit
    builder = TrackBuilder(old_ir)
    return buildtracks!(builder)
end


"""
Construct IR with the same interface as `f(args...)`, returing an error that this method can't be
tracked.
"""
function error_ir(F, Args...)
    # create empty IR which matches the (non-existing) signature given by f(args)
    dummy(Args...) = nothing
    ir = IRTools.empty(IR(IRTools.meta(Tuple{Core.Typeof(dummy), Core.Typeof.(Args)...})))
    self = IRTools.argument!(ir)
    arg_values = ntuple(_ -> IRTools.argument!(ir), length(Args))
    error_result = push!(ir, DCGCall.trackingerror(self, arg_values...))
    IRTools.return!(ir, error_result)
    return ir
end


"""
    _recordnestedcall(Ctx, F, Args...)

The @dynamo/generated function actually calling the transformed IR.  Returns a tuple of return value
and `GraphRecorder`.
"""
function _recordnestedcall! end

@dynamo function _recordnestedcall!(Rec, F, Args...)
    ir = IR(F, Args...)
    
    if isnothing(ir)
        return error_ir(F, Args...)
    else
        new_ir = transform_ir(ir)
        # @coreshow new_ir
        return new_ir
    end
end


function recordnestedcall(ctx::AbstractTrackingContext, f_repr::TapeExpr,
                          args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    recorder = GraphRecorder(ctx)
    result = _recordnestedcall!(recorder, f, args...)
    node = finalize!(recorder, result, f_repr, args_repr, info)
    return node::NestedCallNode{typeof(result)}
end


"""
    track([ctx, ]f, args...) -> Union{PrimitiveCallNode, NestedCallNode}

Evaluate `f(args...)`, while keeping track of the IR evaluation sequence.  Returns some kind of
node, depending on whether the call was primitive or nested.

Intrinsic functions cannot be tracked.
"""
track(f, args...) = track(DEFAULT_CTX, f, args...)

function track(ctx::AbstractTrackingContext, f, args...)
    f_repr, args_repr = TapeConstant(f), TapeConstant.(args)
    recorder = GraphRecorder(ctx)
    return trackedcall(recorder, f_repr, args_repr, NO_INDEX)
end


"""
    trackedreturn(ctx, arg_repr, info)

Construct a node tracking a return statement (`return arg1`).  Overloadable.
"""
trackedreturn(::AbstractTrackingContext, arg_repr::TapeExpr, info::NodeInfo) =
    ReturnNode(arg_repr, info)

function trackedreturn(recorder::GraphRecorder, arg_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedreturn(recorder.context, arg_repr, info)
    return node::ReturnNode
end


"""
    trackedjump(ctx, target, args_repr, cond_repr, info)

Construct a node tracking a jump (`branch target (arg1, ...)`).  Overloadable.
"""
trackedjump(::AbstractTrackingContext, target::Int, args_repr::ArgumentTuple{TapeValue},
            cond_repr::TapeExpr, info::NodeInfo) =
                JumpNode(target, args_repr, cond_repr, info)

function trackedjump(recorder::GraphRecorder, target::Int, args_repr::ArgumentTuple{TapeValue},
                     cond_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedjump(recorder.context, target, args_repr, cond_repr, info)
    return node::JumpNode
end


"""
    trackedspecial(ctx, form_repr, info)

Construct a node tracking a special call (e.g., `Expr(:inline, ...)`).  Overloadable.
"""
trackedspecial(::AbstractTrackingContext, form_repr::TapeExpr, info::NodeInfo) =
    SpecialCallNode(form_repr, info)

function trackedspecial(
    recorder::GraphRecorder, form_repr::TapeExpr{T}, location::IRIndex) where {T}
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedspecial(recorder.context, form_repr, info)
    return node::DataFlowNode{T}
end


"""
    trackedconstant(ctx, const_repr, info)

Construct a node tracking a constant value.  Overloadable.
"""
trackedconstant(::AbstractTrackingContext, const_repr::TapeExpr, info::NodeInfo) =
    ConstantNode(const_repr, info)

function trackedconstant(
    recorder::GraphRecorder, const_repr::TapeExpr{T}, location::IRIndex) where {T}
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedconstant(recorder.context, const_repr, info)
    return node::DataFlowNode{T}
end


"""
    trackedargument(ctx, arg_repr, number, info)

Construct a node tracking a function argument.  Overloadable.
"""
trackedargument(::AbstractTrackingContext, arg_repr::TapeExpr,
                parent_branch::Union{ControlFlowNode, Nothing}, number::Int, info::NodeInfo) =
    ArgumentNode(arg_repr, parent_branch, number, info)

function trackedargument(recorder::GraphRecorder, arg_repr::TapeExpr{T},
                         parent_branch::Union{ControlFlowNode, Nothing}, number::Int,
                         location::IRIndex) where {T}
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedargument(recorder.context, arg_repr, parent_branch, number, info)
    return node::DataFlowNode{T}
end


"""
    trackedprimitive(ctx, f_repr, args_repr, info)
    trackedprimitive(ctx, result, f_repr, args_repr, info)

Construct a node tracking a primitive function call.  Overloadable.  The second version allows to
provide the result of `f(args)` to avoid calling `f` twice, if that has already been done in
`trackedcall`.

See also: [`trackedcall`](@ref)
"""
function trackedprimitive(::AbstractTrackingContext, f_repr::TapeExpr,
                          args_repr::ArgumentTuple{TapeExpr}, info::NodeInfo)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    call = TapeCall(f(args...), f_repr, args_repr)
    return PrimitiveCallNode(call, info)
end

function trackedprimitive(::AbstractTrackingContext, result::T, f_repr::TapeExpr,
                          args_repr::ArgumentTuple{TapeExpr}, info::NodeInfo) where {T}
    call = TapeCall(result, f_repr, args_repr)
    return PrimitiveCallNode(call, info)
end


"""
    trackednested(ctx, f_repr, args_repr, info)

Construct a node tracking a nested function call.  Overloadable.

To record recursively, you should use [`recordnestedcall`](@ref).

See also: [`trackedcall`](@ref),
"""
function trackednested(ctx::AbstractTrackingContext, f_repr::TapeExpr,
                       args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    return recordnestedcall(ctx, f_repr, args_repr, info)
end


"""
    trackedcall(ctx, f_repr, args_repr, info)

Construct a node tracking any function call.  Overloadable.

This must perform the decision whether to record a primitive call, or recur and record a nested
call (for which you should use [`recordnestedcall`](@ref)).

See also: [`trackedprimitive`](@ref), [`trackednested`](@ref)
"""
function trackedcall(ctx::AbstractTrackingContext, f_repr::TapeExpr,
                     args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    if isbuiltin(f) || !canrecur(ctx, f, args...) 
        return trackedprimitive(ctx, f_repr, args_repr, info)::DataFlowNode
    else
        return trackednested(ctx, f_repr, args_repr, info)::DataFlowNode
    end
end

function trackedcall(recorder::GraphRecorder, f_repr::TapeExpr,
                     args_repr::ArgumentTuple{TapeValue}, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedcall(recorder.context, f_repr, args_repr, info)
    return node::DataFlowNode
end


"""
    canrecur(ctx, f, args...)

Decide whether `f(args...)` can be recursively tracked (within `ctx`).
"""
canrecur(ctx::AbstractTrackingContext, f, args...) = !isbuiltin(f)







"""
    @code_tracked f(args...)

Convenience macro similar to `@code_ir` or `@code_lowered`.  Retrieves the transformed IR with added
tracking functionality.
"""
macro code_tracked(ex)
    # from https://github.com/MikeInnes/IRTools.jl/blob/5fe0052795dab8b520085382ccd2eb8197b8f6d0/src/reflection/reflection.jl#L177
    Meta.isexpr(ex, :call) || error("Only function calls allowed!")
    f, args = ex.args[1], ex.args[2:end]
    ir = :(IRTools.Inner.code_ir($(esc(f)), IRTools.Inner.typesof($(esc.(args)...))))
    return :(transform_ir($ir))
end
