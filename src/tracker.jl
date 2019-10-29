using IRTools
using IRTools: IR, @dynamo


"""Construct the transformed IR with tracking statements from `old_ir`."""
function transform_ir(old_ir::IR)
    IRTools.explicitbranch!(old_ir) # make implicit jumps explicit
    builder = TrackBuilder(old_ir)
    return build_tracks!(builder)
end


"""
Construct IR with the same interface as `F(args...)`, returing an error that this method can't be
tracked.
"""
function error_ir(F, args...)
    # create empty IR which matches the (non-existing) signature given by f(args)
    dummy(args...) = nothing
    ir = IRTools.empty(IR(IRTools.meta(Tuple{Core.Typeof(dummy), Core.Typeof.(args)...})))
    self = IRTools.argument!(ir)
    arg_values = ntuple(_ -> IRTools.argument!(ir), length(args))
    error_result = push!(ir, DCGCall.trackingerror(self, arg_values...))
    IRTools.return!(ir, error_result)
    return ir
end


@doc """
    track(f, args...) -> result, graph

Evaluate `f(args...)`, while keeping track of the IR evaluation sequence in a `GraphTape`.  
Returns a tuple of the return value and the tape.

Intrinsic functions cannot be tracked.
""" track

@dynamo function track(ctx::Type{T}, F, args...) where {T<:TrackingContext}
    # Core.println("handling $F with args $args")
    ir = IR(F, args...)

    if isnothing(ir)
        return error_ir(F, args...)
    else
        new_ir = track_ir(ctx, ir)
        # @coreshow new_ir
        return new_ir
    end
end

track(f, args...) = track(DefaultTrackingContext, f, args)



