import Cassette
import Base: push!
using ChainRules



Cassette.@context ForwardTraceCtx

abstract type AbstractTracker end

function trace(tracker::AbstractTracker, f, args...)
    ctx = Cassette.disablehooks(ForwardTraceCtx(metadata = tracker))
    return Cassette.overdub(ctx, f, args...)
end

function Cassette.overdub(ctx::ForwardTraceCtx, f, args...)
    v = extract(ctx, f, args...)
    if v !== nothing
        result, metadata = v
        push!(tracker, metadata)
        return result
    else
        Cassette.recurse(ctx, f, args...)
    end
end

function Cassette.overdub(ctx::ForwardTraceCtx, f::Core.IntrinsicFunction, args...)
    return Cassette.fallback(ctx, f, args...)
end




struct CallTracker <: AbstractTracker
    tape::Vector{Expr}
end

CallTracker() = CallTracker(Expr[])

function extract(ctx::, f, args...)
    println(args)
    return Cassette.recurse(ctx, f, args...), Expr(:call, nameof(f), args...)
end

function push!(tracker::CallTracker, expr)
    push!(tracker.tape, expr)
end

function track(f, args...)
    tracker = CallTracker()
    trace(tracker, f, args...)
    tracker.tape
end




mutable struct FDiffTracker <: AbstractTracker
    tape::Float64
end

FDiffTracker() = FDiffTracker(0)

function extract(tracker::FDiffTracker, f, args...)
    rule = ChainRules.frule(f, args...)
    if rule !== nothing
        Ω, dΩ = rule
        println("$f: $(dΩ(args...))")
        return Ω, dΩ(args...)
    else
        return nothing
    end
end

function push!(tracker::FDiffTracker, Δ::Float64)
    tracker.tape = Δ
end

function D(f, x...)
    tracker = FDiffTracker()
    trace(tracker, f, x...)
    return tracker.tape
end
