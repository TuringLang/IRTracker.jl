using Test
using DynamicComputationGraphs
using IRTools: @code_ir, explicitbranch!
using Distributions
using Random
using ChainRules

import DynamicComputationGraphs: canrecur, tracknested


# typed equality comparison
≅(x::T, y::T) where {T} = x == y
≅(x, y) = false





@testset "DynamicComputationGraphs" begin
    ########### Basic sanity checks #################
    @testset "sanity checks" begin
        let call = track(Core.Intrinsics.add_int, 1, 2)
            @test call isa PrimitiveCallNode
            @test value(call) ≅ 3
        end
        
        f(x) = x + 1
        let call = track(f, 42)
            # @test node.valu isa Tuple{Int, GraphTape}
            @test call isa NestedCallNode
            @test value(call) ≅ 43
            
            println("Trace of `f(42)` for visual inspection:")
            printlevels(call, 3)
            println("\n")
            println(@code_ir f(42))
            println("\n")
        end
        
        geom(n, β) = rand() < β ? n : geom(n + 1, β)
        let call = track(geom, 3, 0.5)
            @test call isa NestedCallNode
            @test value(call) isa Int
            
            println("Trace of `geom(3, 0.6)` for visual inspection:")
            printlevels(call, 3)
            println("\n")
            println(@code_ir geom(3, 0.6))
            println("\n")
        end

        weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)
        let call = track(weird, 3)
            @test call isa NestedCallNode
            @test value(call) isa Int
        end

        function test1(x)
            t = (x, x)
            t[1] + 1
        end
        let call = track(test1, 42)
            @test call isa NestedCallNode
            @test value(call) ≅ 43
        end

        function test2(x)
            if x < 0
                return x + 1
            else
                return x - 1 #sum([x, x])
            end
        end
        let call = track(test2, 42)
            @test call isa NestedCallNode
            @test value(call) ≅ 41
        end

        function test3(x)
            y = zero(x)
            while x > 0
                y += 1
                x -= 1
            end

            return y
        end
        let call = track(test3, 42)
            @test call isa NestedCallNode
            @test value(call) ≅ 42
        end
        
        test4(x) = [x, x]
        let call = track(test4, 42)
            @test call isa NestedCallNode
            @test value(call) ≅ [42, 42]
        end

        test5() = ccall(:rand, Cint, ())
        let call = track(test5)
            @test call isa NestedCallNode
            @test value(call) isa Cint
        end

        # this can fail due to https://github.com/MikeInnes/IRTools.jl/issues/30
        # when it hits the ccall in expm1 in rand(::GammGDSampler)
        sampler = Distributions.GammaGDSampler(Gamma(2, 3))
        test6() = rand(Random.GLOBAL_RNG, sampler)
        let call = track(test6)
            @test call isa NestedCallNode
            @test value(call) isa Float64
        end
        
        function test7()
            p = rand(Beta(1, 1))
            conj = rand(Bernoulli(p))
            if conj
                m = rand(Normal(0, 1))
            else
                m = rand(Gamma(3, 2))
            end

            m += 2
            return rand(Normal(m, 1))
        end
        let call = track(test7)
            @test call isa NestedCallNode
            @test value(call) isa Float64
        end

        # direct test of  https://github.com/MikeInnes/IRTools.jl/issues/30
        @test_skip track(expm1, 1.0) isa NestedCallNode
    end
    
    
    # ########### Errors ###############
    @testset "errors" begin
        @test_throws ErrorException track(isodd)            # no method -- too few args
        @test_throws ErrorException track(isodd, 2, 3)      # no method -- too many args
    end
    
    
    ########### Graph API #################
    @testset "graph api" begin
        f(x) = x + 1 
        # f(42) = 43
        #   @1: [Argument §1:%1] = f
        #   @2: [Argument §1:%2] = 42
        #   @3: [§1:%3] +(@2, 1) = 43
        #     @1: [Argument §1:%1] = +
        #     @2: [Argument §1:%2] = 42
        #     @3: [Argument §1:%3] = 1
        #     @4: [§1:%4] add_int(@2, @3) = 43
        #     @5: [§1:1] return @4 = 43
        #   @4: [§1:1] return @3 = 43

        let call = track(f, 42)
            @test length(call) == 4
            @test length(children(call)) == 4
            @test length(call[3]) == 5
            @test length(children(call[3])) == 5
            @test parent(call[end]) === call
        end
    end


    ########## Contexts #####################
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
        struct DepthLimitContext <: AbstractTrackingContext; level::Int; maxlevel::Int; end
        DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)
        increase_level(ctx::DepthLimitContext) = DepthLimitContext(ctx.level + 1, ctx.maxlevel)

        DynamicComputationGraphs.canrecur(ctx::DepthLimitContext, f, args...) =
            ctx.level < ctx.maxlevel
        
        function DynamicComputationGraphs.tracknested(
            ctx::DepthLimitContext, f, f_repr, args, args_repr, info
        )
            new_ctx = increase_level(ctx)
            return DynamicComputationGraphs.recordnested(new_ctx, f, f_repr, args, args_repr, info)
        end

        let ctx = DepthLimitContext(2), call = track(ctx, f, 42)
            @test length(call) == 5
            @test call[3] isa PrimitiveCallNode
            @test call[4] isa PrimitiveCallNode
        end

        
        # Forward differentiation
        struct FDiffContext <: AbstractTrackingContext end
        DynamicComputationGraphs.canrecur(::FDiffContext, f, args...) = isnothing(frule(f, args...))
        
        let ctx = FDiffContext(), call = track(ctx, f, 42)
            @test length(call) == 5
            @test call[3] isa PrimitiveCallNode
            @test call[4] isa PrimitiveCallNode
        end
    end
end



