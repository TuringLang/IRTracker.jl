using Test
using DynamicComputationGraphs
using IRTools: @code_ir, explicitbranch!
using Distributions
using Random
using ChainRules


# typed equality comparison
≅(x::T, y::T) where {T} = x == y
≅(x, y) = false


@testset "DynamicComputationGraphs" begin
    ########### Basic sanity checks #################
    include("./basics.jl")
    
    
    ########### Graph API #################
    include("./graphapi.jl")


    ########## Contexts #####################
    # include("./contexts.jl")
end



