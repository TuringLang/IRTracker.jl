import DynamicComputationGraphs: canrecur, trackednested, trackedprimitive

@testset "contexts" begin
    f(x) = sin(x) + 1
    # julia> printlevels(track(f, 42), 3)
    # f(42) = 0.08347845208436622
    #   @1: [Argument §1:%1] = f
    #   @2: [Argument §1:%2] = 42
    #   @3: [§1:%3] sin(@2) = -0.9165215479156338
    #     @1: [Argument §1:%1] = sin
    #     @2: [Argument §1:%2] = 42
    #     @3: [§1:%3] float(@2) = 42.0
    #     @4: [§1:%4] sin(@3) = -0.9165215479156338
    #     @5: [§1:1] return @4 = -0.9165215479156338
    #   @4: [§1:%4] +(@3, 1) = 0.08347845208436622
    #     @1: [Argument §1:%1] = +
    #     @2: [Argument §1:%2] = -0.9165215479156338
    #     @3: [Argument §1:%3] = 1
    #     @4: [§1:%4] promote(@2, @3) = (-0.9165215479156338, 1.0)
    #     @5: [§1:%5] Core._apply(+, @4) = 0.08347845208436622
    #     @6: [§1:1] return @5 = 0.08347845208436622
    #   @5: [§1:1] return @4 = 0.08347845208436622


    # Limit recording to a maximum layer
    mutable struct DepthLimitContext <: AbstractTrackingContext
        level::Int
        maxlevel::Int
    end

    DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)

    canrecur(ctx::DepthLimitContext, f, args...) = ctx.level < ctx.maxlevel

    function trackednested(ctx::DepthLimitContext, f_repr::TapeExpr,
                           args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
        ctx.level += 1
        return recordnestedcall(ctx, f_repr, args_repr, info)
        ctx.level -= 1
    end

    let ctx = DepthLimitContext(2), call = track(ctx, f, 42)
        @test length(children(call)) == 5
        @test call[3] isa PrimitiveCallNode
        @test call[4] isa PrimitiveCallNode
        metadata(call)[:bla] = 1
        metadata(call)[:blub] = nothing
        metadata(call[3])[:value] = "sdfd"
        metadata(call[4])[:∂] = 1.234234
        println(call)
    end

    
    # # Backward differentiation
    # struct BDiffContext <: AbstractTrackingContext end

    # function adjoint(call)
    #     ir = IRTools.empty(call.original_ir)
    #     self = IRTools.argument!(ir)
    #     Δ = IRTools.argument!(ir)

        
    #     for child in Iterators.reverse(call)
            
    #     end
        
    #     backward!(nested_call) do node, ancestors
    #         # @show node
    #         # adjoint = get!(metadata(node), :adjoint, 1.0)
    #         pullback = Δ -> sum(pb(Δ) for pb in getmetadata(node, :pullback))
    #         for ancestor in ancestors
    #             push!(getmetadata!(() -> [], node, :pullbacks), pullback)
    #             setmetadata!(node, :pullback, Δ -> pullback(Δ) + old_pullback(Δ))
    #         end
    #     end
        
    #     argument_adjoints = extern.(get.(arguments(nested_call), :adjoint)...)
    #     accumulate!(metadata(nested_call), argument_adjoints)
    # end
    
    # function DynamicComputationGraphs.trackedcall(
    #     ctx::BDiffContext, f, f_repr, args, args_repr, info
    # )
    #     rule = rrule(f, args...)
    #     if !isnothing(rule)
    #         result, pullback = rule        # we can reuse the result from the rrule!
    #         primitive_call = recordprimitive(ctx, result, f, f_repr, args, args_repr, info)
    #         setmetadata!(primitive_call, :pullback, pullback)
    #         return primitive_call
    #     else # this cannot be a primitive, anyway
    #         nested_call = recordnested(ctx, f, f_repr, args, args_repr, info)
    #         pullback = IRTools.func(adjoint(nested_call))
    #         setmetadata!(nested_call, :pullback, pullback)
    #         return nested_call
    #     end
    # end

    # grad(f, args...) = getmetadata(track(BDiffContext(), f, args...), :pullback)(1)
    
    # let ctx = BDiffContext(), call = track(ctx, f, 42)
    #     ∇f = metadata(call)[:adjoint]
    #     @test length(call) == 5
    #     @test call[3] isa PrimitiveCallNode
    #     @test call[4] isa PrimitiveCallNode
    # end
end
