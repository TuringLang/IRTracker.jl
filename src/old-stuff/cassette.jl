using Cassette

Cassette.@context TrackingCtx

import Base: show

struct Call{F, As<:Tuple}
    func::F
    args::As
    body::Vector{Call}
end

Call(f::F, args::As) where {F, As<:Tuple} = Call{F, As}(f, args, Call[])

function show(io::IO, call::Call, indent = 0)
    print(io, " " ^ indent)
    print(io, "(")
    join(io, (call.func, call.args...), " ")
    print(io, ")\n")
    
    for c in call.body
        show(io, c, indent + 2)
    end
end

mutable struct Trace
    root::Union{Nothing, Call}
    parent::Union{Nothing, Call}
end

Trace() = Trace(nothing, nothing)


function Cassette.overdub(ctx::TrackingCtx, f, args...)
    rule = ChainRules.frule(f, args...)

    if rule !== nothing
        println(f)
        # tracker = ctx.metadata
        # call = Call(f, args)
        
        # oldparent = tracker.parent

        # if oldparent === nothing # this was the first call
        #     tracker.root = call
        # else
        #     push!(oldparent.body, call)
        # end

        # tracker.parent = call
        # result = Cassette.recurse(ctx, f, args...)
        # tracker.parent = oldparent

        # return result
        return Cassette.recurse(ctx, f, args...)
    else
        return Cassette.recurse(ctx, f, args...)
    end
    
    # if Cassette.canrecurse(ctx, f, args...)
    #     tracker = ctx.metadata
    #     call = Call(f, args)
        
    #     oldparent = tracker.parent

    #     if oldparent === nothing # this was the first call
    #         tracker.root = call
    #     else
    #         push!(oldparent.body, call)
    #     end

    #     tracker.parent = call
    #     result = Cassette.recurse(ctx, f, args...)
    #     tracker.parent = oldparent
        
    #     return result
    # else
    #     return Cassette.fallback(ctx, f, args...)
    # end
end


function track(f, args...)
    ctx = Cassette.disablehooks(TrackingCtx(metadata = Trace()))
    r = Cassette.@overdub ctx f(args...)
    r, ctx.metadata.root
end


# struct Track{T}
#     value::T
#     tape::Vector{Any}
# end

# function f(x::Track)
#     push!(x.tape, (f, x))
#     Track(f(x.value), x.tape)
# end

# function g(x::Track, y::Track)
#     tape = mergetapes(x.tape, y.tape)
#     push!(tape, (g, x, y))
#     Track(g(x.value, y.value), tape)
# end



using ChainRules


Cassette.@context FDiffCtx

Cassette.metadatatype(::Type{<:FDiffCtx}, ::Type{T}) where {T<:Real} = T

tangent(tx, ctx) = Cassette.hasmetadata(tx, ctx) ?
    Cassette.metadata(tx, ctx) :
    zero(Cassette.untag(tx, ctx))


function forward(f, x...; Δxs = oftype.(x, 1))
    ctx = Cassette.enabletagging(Cassette.disablehooks(FDiffCtx()), f)
    
    tx = Cassette.tag.(x, Ref(ctx), Δxs)
    r = Cassette.overdub(ctx, f, tx...)
    Cassette.untag(r, ctx), ChainRules.extern(tangent(r, ctx))
end


function Cassette.overdub(ctx::FDiffCtx, f, tx)
    x = Cassette.untag(tx, ctx)
    rule = ChainRules.frule(f, x)
    
    if !(rule === nothing)
        Ω, dΩ = rule
        Δx = tangent(tx, ctx)
        return Cassette.tag(Ω, ctx, dΩ(Δx))
    else
        return Cassette.recurse(ctx, f, tx)
    end
end

function Cassette.overdub(ctx::FDiffCtx, f, tx, ty)
    x, y = Cassette.untag(tx, ctx), Cassette.untag(ty, ctx)
    rule = ChainRules.frule(f, x, y)
    
    if !(rule === nothing)
        Ω, dΩ = rule
        Δx, Δy = tangent(tx, ctx), tangent(ty, ctx)
        return Cassette.tag(Ω, ctx, dΩ(Δx, Δy))
    else
        return Cassette.recurse(ctx, f, tx, ty)
    end
end



Cassette.@context BDiffCtx

struct Backpropagator
    back::Any
end

(b::Backpropagator)(Δ) = b.back(Δ)

Cassette.metadatatype(::Type{<:BDiffCtx}, ::Type{T}) where {T<:Real} = Backpropagator

propagator(tx, ctx) = Cassette.hasmetadata(tx, ctx) ?
    Cassette.metadata(tx, ctx) :
    Backpropagator(ΔΩ -> zero(Cassette.untag(tx, ctx)))

function backward(f, x)
    ctx = Cassette.enabletagging(Cassette.disablehooks(BDiffCtx()), f)
    r = Cassette.overdub(ctx, f, Cassette.tag(x, ctx, Backpropagator(ΔΩ -> ΔΩ)))
    Cassette.untag(r, ctx), propagator(r, ctx)
end


function Cassette.overdub(ctx::BDiffCtx, f, tx) where {T}
    x = Cassette.untag(tx, ctx)
    rule = ChainRules.rrule(f, x)

    if !(rule === nothing)
        Ω, dx = rule
        δx = propagator(tx, ctx)
        back = Backpropagator(ΔΩ -> dx(δx(ΔΩ)))
        return Cassette.tag(Ω, ctx, back)
    else
        return Cassette.recurse(ctx, f, tx)
    end
end


function Cassette.overdub(ctx::BDiffCtx, f, tx, ty)
    x, y = Cassette.untag(tx, ctx), Cassette.untag(ty, ctx)
    rule = ChainRules.rrule(f, x, y)

    if !(rule === nothing)
        Ω, (dx, dy) = rule
        δx, δy = propagator(tx, ctx), propagator(ty, ctx)
        back = Backpropagator(ΔΩ -> dx(δx(ΔΩ)) + dy(δy(ΔΩ)))
        return Cassette.tag(Ω, ctx, back)
    else
        return Cassette.recurse(ctx, f, tx, ty)
    end
end



######## Numerical test code from Flux ###########
function ngradient(f, x)
    dfdx = zero(x)
    δ = sqrt(eps())
    tmp = x
    x = tmp - δ/2
    y1 = f(x)
    x = tmp + δ/2
    y2 = f(x)
    x = tmp
    dfdx = (y2 - y1) / δ
    
    return dfdx
end

# function ngradient(f, xs...)
#     xs = collect(xs)
#     Δs = similar(xs)
#     δ = sqrt(eps())
    
#     for i in eachindex(xs)
#         tmp = xs[i]
#         xs[i] = tmp - δ/2
#         y1 = f(xs...)
#         xs[i] = tmp + δ/2
#         y2 = f(xs...)
#         xs[i] = tmp
#         Δs[i] = (y2 - y1) / δ
#     end
    
#     return Δs
# end

gradcheck(f, x, dfdx) = isapprox(ngradient(f, x), dfdx, rtol = 1e-5, atol = 1e-5)
# gradcheck(f, xs, ∇f) = all(isapprox.(ngradient(f, xs...), ∇f, rtol = 1e-5, atol = 1e-5))

# f(x) = 9.5 * cos(x)
# h(x) = -1 ≤ x ≤ 1 ? x^2 / 2 : abs(x) - 1/2
# D(f, x) = DynamicComputationGraphs.forward(f, x)(oftype(x, 1))[2]
# D(f, x) = DynamicComputationGraphs.backward(f, x)[2](oftype(x, 1))
# DynamicComputationGraphs.gradcheck(f, 1, D(h, 1))

# D(sin, 1) === cos(1)
# D(x -> D(sin, x), 1) === -sin(1)
# D(x -> sin(x) * cos(x), 1) === cos(1)^2 - sin(1)^2
# D(x -> x * D(y -> x * y, 1), 2) === 4
# D(x -> x * D(y -> x * y, 2), 1) === 2
