@testset "graph api" begin
    let call = track(x -> x + 1, 42)
        # ⟨getfield(Main, Symbol("##15#16"))()⟩(⟨42⟩) = 43
        #   @1: [Argument §1:%1] = getfield(Main, Symbol("##15#16"))()
        #   @2: [Argument §1:%2] = 42
        #   @3: [§1:%3] ⟨+⟩(@2, ⟨1⟩) = 43
        #     @1: [Argument §1:%1] = +
        #     @2: [Argument §1:%2] = 42
        #     @3: [Argument §1:%3] = 1
        #     @4: [§1:%4] ⟨add_int⟩(@2, @3) = 43
        #     @5: [§1:&1] return @4 = 43
        #   @4: [§1:&1] return @3 = 43
        
        @test length(getchildren(call)) == 4
        @test length(getchildren(call[3])) == 5
        @test getparent(call[end]) == call
        
        @test referenced.(getchildren(call)) == [call[[]], call[[]], call[[2]], call[[3]]]
        @test referenced(call[3][2], Preceding)  == AbstractNode[]
        @test referenced(call[3][2], Parent) == call[[2]]
        @test referenced(call[3][4], Preceding) == call[3][[2, 3]]
        @test referenced(call[3][4], Parent) == AbstractNode[]
        @test referenced(call[3][4], Union{Preceding, Parent}) == call[3][[2, 3]]

        @test backward(call[end], Preceding) == call[[3, 2]]
        @test backward(call[3][5], Preceding) == call[3][[4, 2, 3]]
        @test backward(call[3][5], Union{Preceding, Parent}) == [call[3][[4, 2, 3]]; call[2]]

        @test dependents.(getchildren(call)) == [call[[]], call[[3]], call[[4]], call[[]]]
        @test forward.(getchildren(call)) == [call[[]], call[[3, 4]], call[[4]], call[[]]]
    end


    let call3 = track(union, [1], [2])
        for child in getchildren(call3)
            @test all(child in dependents(r) for r in referenced(child))
            @test all(child in referenced(d) for d in dependents(child))
        end
    end
end
