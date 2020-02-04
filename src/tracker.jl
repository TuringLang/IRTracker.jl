using IRTools
using IRTools: IR, inlineable!, pis!, slots!, varargs!
using IRTools.Inner: argnames!, update!



"""
    transform(old_ir)

Construct the transformed IR with tracking statements from `old_ir`.

See [`@code_tracked`](@ref) for inspecting the result.
"""
function transform(old_ir::IR)
    IRTools.explicitbranch!(old_ir) # make implicit jumps explicit
    builder = TrackBuilder(old_ir)
    return buildtracks!(builder)
end


"""
    _recordnestedcall!(recorder, f, args...)

The generated function actually calling the transformed IR, with an additional `GraphRecorder`
on which the child nodes are stored.
"""
@generated function _recordnestedcall!(recorder::GraphRecorder, f, args...)
    T = Tuple{f, args...}
    meta = IRTools.meta(T)
    
    if isnothing(meta)
        return :(trackederror(recorder, f, args))
    else
        tracked = transform(IR(meta))
        original_argnames = meta.code.slotnames[2:meta.nargs]
        argnames!(meta, Symbol("#self#"), :recorder, :f, :args)
        tracked = varargs!(meta, tracked, 3)
        return update!(meta.code, tracked)
    end
end


"""
    recordnestedcall!(ctx, f_repr, args_repr, info)

Construct a `NestedCallNode` from the call represented by `f_repr` on `args_repr`, by tracking using
`ctx`.
"""
@inline function recordnestedcall(ctx::AbstractTrackingContext, f_repr::TapeExpr,
                                  args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    recorder = GraphRecorder(ctx)
    result = _recordnestedcall!(recorder, f, args...)
    node = finalize!(recorder, result, f_repr, args_repr, info)
    return node
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
@inline trackedreturn(::AbstractTrackingContext, arg_repr::TapeExpr, info::NodeInfo) =
    ReturnNode(arg_repr, info)

@inline function trackedreturn(recorder::GraphRecorder, arg_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedreturn(recorder.context, arg_repr, info)
    return node
end


"""
    trackedjump(ctx, target, args_repr, cond_repr, info)

Construct a node tracking a jump (`branch target (arg1, ...)`).  Overloadable.
"""
@inline trackedjump(::AbstractTrackingContext, target::Int, args_repr::ArgumentTuple{TapeValue},
                    cond_repr::TapeExpr, info::NodeInfo) =
                        JumpNode(target, args_repr, cond_repr, info)

@inline function trackedjump(recorder::GraphRecorder, target::Int,
                             args_repr::ArgumentTuple{TapeValue},
                             cond_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedjump(recorder.context, target, args_repr, cond_repr, info)
    return node
end


"""
    trackedspecial(ctx, form_repr, info)

Construct a node tracking a special call (e.g., `Expr(:inline, ...)`).  Overloadable.
"""
@inline trackedspecial(::AbstractTrackingContext, form_repr::TapeExpr, info::NodeInfo) =
    SpecialCallNode(form_repr, info)

@inline function trackedspecial(recorder::GraphRecorder, form_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedspecial(recorder.context, form_repr, info)
    return node
end


"""
    trackedconstant(ctx, const_repr, info)

Construct a node tracking a constant value.  Overloadable.
"""
@inline trackedconstant(::AbstractTrackingContext, const_repr::TapeExpr, info::NodeInfo) =
    ConstantNode(const_repr, info)

@inline function trackedconstant(
    recorder::GraphRecorder, const_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedconstant(recorder.context, const_repr, info)
    return node
end


"""
    trackedargument(ctx, arg_repr, number, info)

Construct a node tracking a function argument.  Overloadable.
"""
@inline trackedargument(::AbstractTrackingContext, arg_repr::TapeExpr,
                        parent_branch::Union{ControlFlowNode, Nothing},
                        number::Int, info::NodeInfo) =
    ArgumentNode(arg_repr, parent_branch, number, info)

@inline function trackedargument(recorder::GraphRecorder, arg_repr::TapeExpr,
                                 parent_branch::Union{ControlFlowNode, Nothing}, number::Int,
                                 location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedargument(recorder.context, arg_repr, parent_branch, number, info)
    return node
end


"""
    trackedprimitive(ctx, f_repr, args_repr, info)
    trackedprimitive(ctx, result, f_repr, args_repr, info)

Construct a node tracking a primitive function call.  Overloadable.  The second version allows to
provide the result of `f(args)` to avoid calling `f` twice, if that has already been done in
`trackedcall`.

See also: [`trackedcall`](@ref)
"""
@inline function trackedprimitive(::AbstractTrackingContext, f_repr::TapeExpr,
                                  args_repr::ArgumentTuple{TapeExpr}, info::NodeInfo)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    call = TapeCall(f(args...), f_repr, args_repr)
    return PrimitiveCallNode(call, info)
end

@inline function trackedprimitive(::AbstractTrackingContext, result::T, f_repr::TapeExpr,
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
@inline function trackednested(ctx::AbstractTrackingContext, f_repr::TapeExpr,
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
@inline function trackedcall(ctx::AbstractTrackingContext, f_repr::TapeExpr,
                             args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    f, args = getvalue(f_repr), getvalue.(args_repr)
    if isbuiltin(f) || !canrecur(ctx, f, args...) 
        return trackedprimitive(ctx, f_repr, args_repr, info)
    else
        return trackednested(ctx, f_repr, args_repr, info)
    end
end

@inline function trackedcall(recorder::GraphRecorder, f_repr::TapeExpr,
                             args_repr::ArgumentTuple{TapeValue}, location::IRIndex)
    info = NodeInfo(recorder.original_ir, location, recorder.rootnode)
    node = trackedcall(recorder.context, f_repr, args_repr, info)
    return node
end


"""
    trackederror(ctx, f, args)

Raise an error that `f` cannot be tracked with arguments `args`.  Overloadable.
"""
trackederror(ctx::AbstractTrackingContext, f, args) = throw(MethodError(f, args))
trackederror(recorder::GraphRecorder, f, args) = trackederror(recorder.context, f, args)


"""
    canrecur(ctx, f, args...)

Decide whether `f(args...)` can be recursively tracked (within `ctx`).
"""
@inline canrecur(ctx::AbstractTrackingContext, f, args...) = !isbuiltin(f)


"""
    isbuiltin(f)

Determine if the function `f` is a Julia builtin function (an intrinsic, a `Core.Builtin`, or from 
`Core.Compiler`).
"""
@inline function isbuiltin(f)
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    F = typeof(f)
    mod = Base.typename(F).module
    return ((F <: Core.Builtin) || (mod === Core.Compiler))
end

@inline isbuiltin(f::Core.IntrinsicFunction) = true


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
    return :(transform($ir))
end
