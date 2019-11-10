using IRTools
using IRTools: IR, @dynamo


"""Construct the transformed IR with tracking statements from `old_ir`."""
function transform_ir(old_ir::IR)
    IRTools.explicitbranch!(old_ir) # make implicit jumps explicit
    builder = TrackBuilder(old_ir)
    return build_tracks!(builder)
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


@dynamo function _recordnestedcall(Ctx, F, Args...)
    ir = IR(F, Args...)
    
    if isnothing(ir)
        return error_ir(F, Args...)
    else
        new_ir = transform_ir(ir)
        # @coreshow new_ir
        return new_ir
    end
end


"""
    track([ctx, ]f, args...) -> Union{PrimitiveCallNode, NestedCallNode}

Evaluate `f(args...)`, while keeping track of the IR evaluation sequence.  Returns some kind of
node, depending on whether the call was primitive or nested.

Intrinsic functions cannot be tracked.
"""
track(f, args...) = track(DEFAULT_CTX, f, args...)
track(ctx::AbstractTrackingContext, f, args...) =
    trackcall(ctx, f, TapeConstant(f), args, TapeConstant.(args), NodeInfo())


"""
    trackcall(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info)

Return a node representing the call of `f` on `args`.
"""
function trackcall(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info)
    # println("Tracking ", f, " with args ", args)

    if isbuiltin(f, args) || !canrecur(ctx, f, args...) 
        trackprimitive(ctx, f, f_repr, args, args_repr, info)
    else
        tracknested(ctx, f, f_repr, args, args_repr, info)
    end
end


"""
    trackprimitive(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info)

Track `f(args...)` as a primitive call within `ctx`.
"""
trackprimitive(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info) =
    recordprimitive(ctx, f, f_repr, args, args_repr, info)


"""
    tracknested(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info)

Track `f(args...)` as a nested call within `ctx`, recursively tracking calls within it.
"""
tracknested(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info) =
    recordnested(ctx, f, f_repr, args, args_repr, info)


"""
    canrecur(ctx::AbstractTrackingContext, f, args...)

Decide whether `f(args...)` can be recursively tracked (within `ctx`).
"""
canrecur(ctx::AbstractTrackingContext, f, args...) = !isbuiltin(ctx, f, args...)


"""Fallback implementation for `trackprimitive` -- don't overload this!"""
function recordprimitive(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info)
    result = f(args...)
    tapecall = TapeCall(result, f_repr, collect(args_repr))
    return PrimitiveCallNode(tapecall, info)
end

"""Fallback implementation for `tracknested` -- don't overload this!"""
function recordnested(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, info)
    result, recorder = _recordnestedcall(ctx, f, args...)
    return finish_recording(recorder, result, f_repr, args_repr, info)
end





