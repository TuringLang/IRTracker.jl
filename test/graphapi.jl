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
        
        @test datapath(call) ≅ call[[2, 3]]
    end
end
