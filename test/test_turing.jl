using Distributions
using DynamicPPL
using Turing


const observations = randn(10) .+ range(1, step = 0.3, length = 10)


@model KalmanFilter(y, ::Type{Tx}=Vector{Float64}) where {Tx} = begin
    T = length(y)
    x = Tx(undef, T)

    x[1] ~ Normal(0, 0.5)
    y[1] ~ Normal(x[1], 0.2)

    for t = 2:T
        x[t] ~ Normal(x[t-1], 0.5)
        y[t] ~ Normal(x[t], 0.2)
    end

    return y
end

@model MutatingKalmanFilter(y, ::Type{Tx}=Vector{Float64}) where {Tx} = begin
    T = length(y)
    x = Tx(undef, T)

    x[1] ~ Normal()
    x1 = 0.5 * x[1]
    x[1] = x1
    y[1] ~ Normal(x1, 0.2)

    for t = 2:T
        x[t] ~ Normal()
        xt = x[t] + x[t-1]
        xt = xt / 2
        x[t] = xt
        y[t] ~ Normal(xt, 0.2)
    end

    return y
end


# See AutoGibbs
const ModelEval = Union{typeof(DynamicPPL.evaluate_singlethreaded),
                  typeof(DynamicPPL.evaluate_multithreaded)}


struct AutoGibbsContext{F} <: AbstractTrackingContext end

IRTracker.canrecur(ctx::AutoGibbsContext{F}, ::Model{F}, args...) where {F} = true
IRTracker.canrecur(ctx::AutoGibbsContext{F}, ::ModelEval, ::Model{F}, args...) where {F} = true
IRTracker.canrecur(ctx::AutoGibbsContext{F}, f::F, args...) where {F} = true
IRTracker.canrecur(ctx::AutoGibbsContext, f, args...) = false

trackmodel(model::Model{F}) where {F} = track(AutoGibbsContext{F}(), model)


@testset "Turing" begin
    # with depth 7 this fails in the Dict's _setindex! method due to unitialized values
    # [1] getindex at ./array.jl:744 [inlined]
    # [2] _iterate at ./dict.jl:675 [inlined]
    # [3] iterate at ./dict.jl:677 [inlined]
    # [4] deepcopy_internal(::Dict{String,BitArray{1}}, ::IdDict{Any,Any}) at ./deepcopy.jl:112
    # [5] deepcopy at ./deepcopy.jl:30 [inlined]

    @test track(DepthLimitContext(6), KalmanFilter(observations)) isa NestedCallNode
    @test track(DepthLimitContext(6), MutatingKalmanFilter(observations)) isa NestedCallNode
    
    @test trackmodel(KalmanFilter(observations)) isa NestedCallNode
    @test trackmodel(MutatingKalmanFilter(observations)) isa NestedCallNode
end



