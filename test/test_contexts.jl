@testset "depth limiting" begin
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


    # Limit recording to a maximum layer -- see implementation in src/trackingcontext.jl
    let ctx = DepthLimitContext(2), call = track(ctx, f, 42)
        @test length(getchildren(call)) == 5
        @test call[3] isa PrimitiveCallNode
        @test call[4] isa PrimitiveCallNode
        getmetadata(call)[:bla] = 1
        getmetadata(call)[:blub] = nothing
        getmetadata(call[3])[:value] = "sdfd"
        getmetadata(call[4])[:∂] = 1.234234
    end

    let ctx = DepthLimitContext(2), call = track(ctx, union!, [1], [2])
        @test all(!(c isa NestedCallNode) for c in getchildren(call))
    end
end
