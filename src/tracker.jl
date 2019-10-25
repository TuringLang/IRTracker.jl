using IRTools
using IRTools: IR, @dynamo

function track_ir(old_ir::IR)
    IRTools.explicitbranch!(old_ir) # make implicit jumps explicit
    builder = TrackBuilder(old_ir)
    return build_tracks!(builder)
end


function error_ir(F, args...)
    # create empty IR which matches the (non-existing) signature given by f(args)
    dummy(args...) = nothing
    ir = IRTools.empty(IR(IRTools.meta(Tuple{Core.Typeof(dummy), Core.Typeof.(args)...})))
    
    self = IRTools.argument!(ir)
    arg_values = ntuple(_ -> IRTools.argument!(ir), length(args))

    if F <: Core.IntrinsicFunction
        error_result = push!(ir, DCGCall.print_intrinsic_error(self, arg_values...))
        IRTools.return!(ir, error_result)
        return ir
    else
        error_result = push!(ir, IRTools.xcall(:error, "Can't track ", F,
                                               " with args ", join(args, ", ")))
        IRTools.return!(ir, error_result)
        return ir
    end
end


@doc """
    track(f, args...)

Evaluate `f(args...)`, while keeping track of the IR evaluation sequence in a `GraphTape`.  
Returns a tuple of the return value and the tape.

Primitive functions cannot be tracked.
""" track

@dynamo function track(F, args...)
    # Core.println("handling $F with args $args")
    ir = IR(F, args...)

    if isnothing(ir)
        return error_ir(F, args...)
    else
        new_ir = track_ir(ir)
        # @coreshow new_ir
        return new_ir
    end
end



