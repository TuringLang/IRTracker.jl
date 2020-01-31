using Turing
using Distributions


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


@testset "sanity checks" begin
    @test track(KalmanFilter(observations)) isa NestedCallNode
    @test track(MutatingKalmanFilter(observations)) isa NestedCallNode
end
