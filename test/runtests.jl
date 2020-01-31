using Test
using IRTracker


@testset "IRTracker" begin
    ########### Basic sanity checks #################
    include("./test_basics.jl")
    
    
    ########### Graph API #################
    include("./test_graphapi.jl")


    ########## Contexts #####################
    @testset "contexts" begin
        include("test_contexts.jl")
        include("test_backward_ad.jl")
    end
end


# type stability inspection:
# using IRTracker
# f(x) = x + 1
# ctx = IRTracker.DEFAULT_CTX
# f_repr, args_repr =  TapeConstant(f), (TapeConstant(1),)
# recorder = IRTracker.GraphRecorder(ctx)
# @code_warntype track(f, 1)
# @code_warntype IRTracker._recordnestedcall!(recorder, f, (1,))
# @inferred NestedCallNode{Int} track(f, 1)
