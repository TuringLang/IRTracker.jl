using Test
using DynamicComputationGraphs
using IRTools: @code_ir
using Distributions

@testset "DynamicComputationGraphs" begin
    
    ########### Basic sanity checks #################
    @testset "sanity checks" begin
        # f(x) = x + 1
        # let (r, graph) = track(f, 42)
        #     @test (r, graph) isa Tuple{Int, GraphTape}
        #     @test r == 43
        # end

        # weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)
        # @test track(weird, 3) isa Tuple{Int, GraphTape}

        # geom(n, β) = rand() < β ? n : geom(n + 1, β)
        # @test track(geom, 3, 0.5) isa Tuple{Int, GraphTape}

        # function test1(x)
        #     t = (x, x)
        #     t[1] + 1
        # end
        # let (r, graph) = track(test1, 42)
        #     @test (r, graph) isa Tuple{Int, GraphTape}
        #     @test r == 43
        # end

        # function test2(x)
        #     if x < 0
        #         return x + 1
        #     else
        #         return x - 1 #sum([x, x])
        #     end
        # end
        # let (r, graph) = track(test2, 42)
        #     @test (r, graph) isa Tuple{Int, GraphTape}
        #     @test r == 41
        # end

        # function test3(x)
        #     y = zero(x)
        #     while x > 0
        #         y += 1
        #         x -= 1
        #     end

        #     return y
        # end
        # let (r, graph) = track(test3, 42)
        #     @test (r, graph) isa Tuple{Int, GraphTape}
        #     @test r == 42
        # end
        
        test4(x) = [x, x]
        let (r, graph) = track(test4, 42)
            @test (r, graph) isa Tuple{Vector{Int}, GraphTape}
            @test r == [42, 42]
        end

        # function test5()
        #     p = rand(Beta(1, 1))
        #     conj = rand(Bernoulli(p))
        #     if conj
        #         m = rand(Normal(0, 1))
        #     else
        #         m = rand(Gamma(3, 2))
        #     end

        #     m += 2
        #     return Normal(m, 1)
        # end
        # let (r, graph) = track(test5)
        #     @test (r, graph) isa Tuple{Float64, GraphTape}
        # end


        # check visible result
        # result, graph = track(geom, 3, 0.6)
        # @show @code_ir geom(3, 0.6)
        # printlevels(graph, 2)
        # println("\n")

        # result, graph = track(f, 10)
        # @show @code_ir f(10)
        # printlevels(graph, 2)
        # println("\n")
        
    end



    ########### Graph API #################
    # @testset "graph api" begin
        # println(IOContext(stdout, :maxlevel => 1), parents(graph[end-1]))
    # end
    
end



