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

"""
    _recordnestedcall(Ctx, F, Args...)

The @dynamo/generated function actually calling the transformed IR.  Returns a tuple of return value
and `GraphRecorder`.
"""
function _recordnestedcall end

@dynamo function _recordnestedcall(Rec, F, Args...)
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

function track(ctx::AbstractTrackingContext, f, args...)
    f_repr, args_repr = TapeConstant(f), TapeConstant.(args)
    recorder = GraphRecorder(ctx)
    return trackedcall(recorder, f, f_repr, args, args_repr, NO_INDEX)
end



function trackedbranch(recorder::GraphRecorder, arg_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(location, recorder.rootnode)
    return ReturnNode(arg_repr, info)
end

function trackedjump(recorder::GraphRecorder, block::Int, args_repr::ArgumentTuple{TapeValue},
                   cond_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(location, recorder.rootnode)
    return JumpNode(block, args_repr, cond_repr, info)
end

function trackedspecialcall(recorder::GraphRecorder, form_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(location, recorder.rootnode)
    return SpecialCallNode(form_repr, info)
end

function trackedconstant(recorder::GraphRecorder, const_repr::TapeExpr, location::IRIndex)
    info = NodeInfo(location, recorder.rootnode)
    return ConstantNode(const_repr, info)
end

function trackedargument(recorder::GraphRecorder, arg_repr::TapeExpr,
                       number::Int, location::IRIndex)
    info = NodeInfo(location, recorder.rootnode)
    return ArgumentNode(arg_repr, number, info)
end

function trackedprimitive(recorder::GraphRecorder, f_repr::TapeExpr,
                        args_repr::ArgumentTuple{TapeExpr}, location::IRIndex)
    info = NodeInfo(location, recorder.rootnode)
    f, args = value(f_repr), value.(args_repr)
    call = TapeCall(f(args...), f_repr, args_repr)
    return PrimitiveCallNode(call, info)
end

function trackednested(recorder::GraphRecorder, f, f_repr::TapeExpr,
                     args, args_repr::ArgumentTuple{TapeValue}, location::IRIndex)
    # f, args = value(f_repr), value.(args_repr)
    call = TapeCall(f_repr, args_repr)
    info = NodeInfo(location, recorder.rootnode)
    rootnode = NestedCallNode(call, Vector{RecursiveNode}(), recorder.original_ir, info)
    
    result, nestedrecorder = _recordnestedcall(GraphRecorder(recorder.context, rootnode), f, args...)
    nestedrecorder.rootnode.call.value[] = result
    return nestedrecorder.rootnode
end

function trackedcall(recorder::GraphRecorder, f, f_repr::TapeExpr,
                   args, args_repr::ArgumentTuple{TapeValue}, location::IRIndex)
    # f, args = value(f_repr), value.(args_repr)
    
    if isbuiltin(f) || !canrecur(recorder.context, f, args...) 
        trackedprimitive(recorder, f_repr, args_repr, location)
    else
        trackednested(recorder, f, f_repr, args, args_repr, location)
    end
end


"""
    canrecur(recorder::GraphRecorder, f, args...)

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
