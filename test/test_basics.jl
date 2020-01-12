# typed equality comparison with `\cong`
≅(x::T, y::T) where {T} = x == y
≅(x, y) = false


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
        
        # println("Trace of `f(42)` for visual inspection:")
        # printlevels(call, 3)
        # println("\n")
        # println(@code_ir f(42))
        # println("\n")
    end
    
    geom(n, β) = rand() < β ? n : geom(n + 1, β)
    let call = track(geom, 3, 0.5)
        @test call isa NestedCallNode
        @test value(call) isa Int
        
        # println("Trace of `geom(3, 0.6)` for visual inspection:")
        # printlevels(call, 3)
        # println("\n")
        # println(@code_ir geom(3, 0.6))
        # println("\n")
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
        conj = rand(Bernoulli(p)) == 1
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



@testset "errors" begin
    @test_throws ErrorException track(isodd)            # no method -- too few args
    @test_throws ErrorException track(isodd, 2, 3)      # no method -- too many args
end
