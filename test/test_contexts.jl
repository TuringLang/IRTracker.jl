import DynamicComputationGraphs: canrecur, tracknested, trackprimitive

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


    # # Limit recording to a maximum layer
    # struct DepthLimitContext <: AbstractTrackingContext; level::Int; maxlevel::Int; end
    # DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)
    # increase_level(ctx::DepthLimitContext) = DepthLimitContext(ctx.level + 1, ctx.maxlevel)

    # DynamicComputationGraphs.canrecur(ctx::DepthLimitContext, f, args...) =
    #     ctx.level < ctx.maxlevel
    
    # function DynamicComputationGraphs.tracknested(
    #     ctx::DepthLimitContext, f, f_repr, args, args_repr, info
    # )
    #     new_ctx = increase_level(ctx)
    #     return recordnested(new_ctx, f, f_repr, args, args_repr, info)
    # end

    # let ctx = DepthLimitContext(2), call = track(ctx, f, 42)
    #     @test length(call) == 5
    #     @test call[3] isa PrimitiveCallNode
    #     @test call[4] isa PrimitiveCallNode
    #     metadata(call)[:bla] = 1
    #     metadata(call)[:blub] = nothing
    #     metadata(call[3])[:value] = "sdfd"
    #     metadata(call[4])[:∂] = 1.234234
    #     println(call)
    # end

    
    # Backward differentiation
    struct BDiffContext <: AbstractTrackingContext end

    function DynamicComputationGraphs.trackcall(
        ctx::BDiffContext, f, f_repr, args, args_repr, info
    )
        rule = rrule(f, args...)
        if !isnothing(rule)
            result, pullback = rule
            # info.metadata[:adjoint] = pullback(1.0)
            info.metadata[:pullback] = pullback
            return recordprimitive(ctx, result, f, f_repr, args, args_repr, info)
        else # this cannot be a primitive, anyway
            # accumulate!(node, ∂) = let meta = metadata(node)
            # meta[:adjoint] = get(meta, :adjoint, 0.0) + ∂
            # end
            
            nested_call = recordnested(ctx, f, f_repr, args, args_repr, info)
            
            backward!(nested_call) do node, ancestors
                # @show node
                # adjoint = get!(metadata(node), :adjoint, 1.0)
                pullback = Δ -> sum(pb(Δ) for pb in getmetadata(node, :pullbacks))
                for ancestor in ancestors
                    push!(getmetadata!(() -> [], node, :pullbacks), pullback)
                    setmetadata!(node, :pullback, Δ -> pullback(Δ) + old_pullback(Δ))
                end
            end
            
            argument_adjoints = extern.(get.(arguments(nested_call), :adjoint)...)
            accumulate!(metadata(nested_call), argument_adjoints)

            return nested_call
        end
    end

    # grad(f, args...) = metadata(track(BDiffContext(), f, args...))[:adjoint]
    
    let ctx = BDiffContext(), call = track(ctx, f, 42)
        ∇f = metadata(call)[:adjoint]
        @test length(call) == 5
        @test call[3] isa PrimitiveCallNode
        @test call[4] isa PrimitiveCallNode
    end
end
