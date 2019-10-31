using Test
using DynamicComputationGraphs
using IRTools: @code_ir
using Distributions
using Random
using ChainRules


# typed equality comparison
≅(x::T, y::T) where {T} = x == y
≅(x, y) = false


@testset "DynamicComputationGraphs" begin

    ########### Errors ###############
    @testset "errors" begin
        @test_throws ErrorException track(isodd)               # no method -- too few args
        @test_throws ErrorException track(isodd, 2, 3)         # no method -- too many args
    end
    
    
    ########### Basic sanity checks #################
    @testset "sanity checks" begin
        let graph = track(Core.Intrinsics.add_int, 1, 2)
            @test graph isa PrimitiveCallNode
            @test value(graph) ≅ 3
        end
        
        f(x) = x + 1
        let graph = track(f, 42)
            # @test node.valu isa Tuple{Int, GraphTape}
            @test graph isa NestedCallNode
            @test value(graph) ≅ 43
            
            println("Trace of `f(42)` for visual inspection:")
            printlevels(graph, 2)
            println("\n")
            @show @code_ir f(42)
            println("\n")
        end
        
        geom(n, β) = rand() < β ? n : geom(n + 1, β)
        let graph = track(geom, 3, 0.5)
            @test graph isa NestedCallNode
            @test value(graph) isa Int
            
            println("Trace of `geom(3, 0.6)` for visual inspection:")
            printlevels(graph, 2)
            println("\n")
            @show @code_ir geom(3, 0.6)
            println("\n")
        end

        weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)
        let graph = track(weird, 3)
            @test graph isa NestedCallNode
            @test value(graph) isa Int
        end

        function test1(x)
            t = (x, x)
            t[1] + 1
        end
        let graph = track(test1, 42)
            @test graph isa NestedCallNode
            @test value(graph) ≅ 43
        end

        function test2(x)
            if x < 0
                return x + 1
            else
                return x - 1 #sum([x, x])
            end
        end
        let graph = track(test2, 42)
            @test graph isa NestedCallNode
            @test value(graph) ≅ 41
        end

        function test3(x)
            y = zero(x)
            while x > 0
                y += 1
                x -= 1
            end

            return y
        end
        let graph = track(test3, 42)
            @test graph isa NestedCallNode
            @test value(graph) ≅ 42
        end
        
        test4(x) = [x, x]
        let graph = track(test4, 42)
            @test graph isa NestedCallNode
            @test value(graph) ≅ [42, 42]
        end

        test5() = ccall(:rand, Cint, ())
        let graph = track(test5)
            @test graph isa NestedCallNode
            @test value(graph) isa Cint
        end
        
        sampler = Distributions.GammaGDSampler(Gamma(2, 3))
        test6() = rand(Random.GLOBAL_RNG, sampler)
        let graph = track(test6)
            @test graph isa NestedCallNode
            @test value(graph) isa Float64
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
        let graph = track(test7)
            @test graph isa NestedCallNode
            @test value(graph) isa Float64
        end
    end



    ########### Graph API #################
    # @testset "graph api" begin
    #     f(x) = x + 1 
    #     # julia> track(f, 42)[2]
    #     # @1: [Argument §1:%1] = f
    #     # @2: [Argument §1:%2] = 42
    #     # @3: [§1:%3] +(@2, 1) = 43
    #     #     @1: [Argument §1:%1] = +
    #     #     @2: [Argument §1:%2] = 42
    #     #     @3: [Argument §1:%3] = 1
    #     #     @4: [§1:%4] add_int(@2, @3) = 43
    #     #     @5: [§1:1] return @4 = 43
    #     # @4: [§1:1] return @3 = 43

    #     let (r, graph) = track(f, 42)
    #         @test length(graph) = 4
    #         @test parents(graph[end]) == [graph[3]]
    #         @test length(children(graph[3])) == 1
    #     end
    # end


    ########## Contexts #####################
    @testset "contexts" begin

    end
end



