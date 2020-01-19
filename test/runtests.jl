using Test
using DynamicComputationGraphs


@testset "DynamicComputationGraphs" begin
    ########### Basic sanity checks #################
    include("./test_basics.jl")
    
    
    ########### Graph API #################
    include("./test_graphapi.jl")


    ########## Contexts #####################
    # include("./test_contexts.jl")
end



