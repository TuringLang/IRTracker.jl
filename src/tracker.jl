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


@dynamo function _track(Ctx, F, Args...)
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
    track(f, args...)

Evaluate `f(args...)`, while keeping track of the IR evaluation sequence in a `GraphTape`.  
Returns a `Node`, depending on whether the call was primitive or nested.

Intrinsic functions cannot be tracked.
"""
track(f, args...) = track(DEFAULT_CTX, f, args...)
track(ctx::AbstractTrackingContext, f, args...) =
    trackinternal(ctx, f, TapeConstant(f), args, TapeConstant.(args), VarIndex(0, 0))

function trackinternal(ctx::AbstractTrackingContext, f, f_repr, args, args_repr, location)
    # println("Tracking ", f, " with args ", args)
    
    if isprimitive(ctx, f, args...)
        result = f(args...)
        tapecall = TapeCall(result, f_repr, collect(args_repr))
        return PrimitiveCallNode(tapecall, location)
    else
        result, subtape = _track(ctx, f, args...)
        tapecall = TapeCall(result, f_repr, collect(args_repr))
        return NestedCallNode(tapecall, subtape, location)
    end
end





