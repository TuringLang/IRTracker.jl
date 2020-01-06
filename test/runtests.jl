using Test
using DynamicComputationGraphs
using IRTools: @code_ir, explicitbranch!
using Distributions
using Random
using ChainRules


# typed equality comparison with `\cong`
≅(x::T, y::T) where {T} = x == y
≅(x, y) = false


@testset "DynamicComputationGraphs" begin
    ########### Basic sanity checks #################
    include("./test_basics.jl")
    
    
    ########### Graph API #################
    # include("./test_graphapi.jl")


    ########## Contexts #####################
    # include("./test_contexts.jl")
end



