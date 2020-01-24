using Test
using DynamicComputationGraphs


@testset "DynamicComputationGraphs" begin
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



