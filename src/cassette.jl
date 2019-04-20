using Cassette

Cassette.@context TrackingCtx

mutable struct Tracker
    root::Union{Nothing, Call}
    parent::Union{Nothing, Call}
end

Tracker() = Tracker(nothing, nothing)


function Cassette.overdub(ctx::TrackingCtx, f, args...)
    if Cassette.canrecurse(ctx, f, args...)
        tracker = ctx.metadata
        call = Call(f, args)
        
        oldparent = tracker.parent

        if oldparent === nothing # this was the first call
            tracker.root = call
        else
            push!(oldparent.body, call)
        end

        tracker.parent = call
        result = Cassette.recurse(ctx, f, args...)
        tracker.parent = oldparent
        
        return result
    else
        return Cassette.fallback(ctx, f, args...)
    end
end


function track(f, args...)
    ctx = Cassette.disablehooks(TrackingCtx(metadata = Tracker()))
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



using DiffRules


Cassette.@context FDiffCtx

Cassette.metadatatype(::Type{<:FDiffCtx}, ::Type{T}) where {T<:Real} = T


tangent(x, ctx) = Cassette.hasmetadata(x, ctx) ?
    Cassette.metadata(x, ctx) :
    zero(Cassette.untag(x, ctx))


function forward(f, xs...)
    ctx = Cassette.enabletagging(Cassette.disablehooks(FDiffCtx()), f)
    
    function (dxs...)
        txs = [Cassette.tag(x, ctx, dx) for (x, dx) in zip(xs, dxs)]
        r = Cassette.overdub(ctx, f, txs...)
        Cassette.untag(r, ctx), tangent(r, ctx)
    end
end


for (M, f, arity) in DiffRules.diffrules()
    M == :Base || continue
    
    if arity == 1
        ∂₁f = DiffRules.diffrule(M, f, :x)
        
        @eval begin
            function Cassette.overdub(ctx::FDiffCtx{T}, f::typeof($f), tx) where {T}
                x = Cassette.untag(tx, ctx)
                dx = tangent(tx, ctx)
                return Cassette.tag(f(x), ctx, $∂₁f * dx)
            end
        end
    elseif arity == 2
        ∂₁f, ∂₂f = DiffRules.diffrule(M, f, :x, :y)
        
        @eval begin
            function Cassette.overdub(ctx::FDiffCtx, f::typeof($f), tx, ty)
                x, y = Cassette.untag(tx, ctx), Cassette.untag(ty, ctx)
                dx, dy = tangent(tx, ctx), tangent(ty, ctx)
                return Cassette.tag(f(x, y), ctx, $∂₁f * dx + $∂₂f * dy)
            end
        end
    end
end


Cassette.@context BDiffCtx

struct Backpropagator
    back::Any
end

(b::Backpropagator)(Δ) = b.back(Δ)

Cassette.metadatatype(::Type{<:BDiffCtx}, ::Type{T}) where {T<:Real} = Backpropagator

propagator(x, ctx) = Cassette.hasmetadata(x, ctx) ?
    Cassette.metadata(x, ctx) :
    Backpropagator(Δ -> zero(x))

function backward(f, x)
    ctx = Cassette.enabletagging(Cassette.disablehooks(BDiffCtx()), f)
    r = Cassette.overdub(ctx, f, Cassette.tag(x, ctx, Backpropagator(Δ -> Δ)))
    Cassette.untag(r, ctx), propagator(r, ctx)
end


for (M, f, arity) in DiffRules.diffrules()
    M == :Base || continue
    
    if arity == 1
        ∂₁f = DiffRules.diffrule(M, f, :x)
        
        @eval begin
            function Cassette.overdub(ctx::BDiffCtx{T}, f::typeof($f), tx) where {T}
                x = Cassette.untag(tx, ctx)
                δx = propagator(tx, ctx)
                back = Backpropagator(Δ -> δx(Δ) * $∂₁f)
                return Cassette.tag(f(x), ctx, back)
            end
        end
    elseif arity == 2
        ∂₁f, ∂₂f = DiffRules.diffrule(M, f, :x, :y)
        
        @eval begin
            function Cassette.overdub(ctx::BDiffCtx, f::typeof($f), tx, ty)
                x, y = Cassette.untag(tx, ctx), Cassette.untag(ty, ctx)
                δx, δy = propagator(tx, ctx), propagator(ty, ctx)
                back = Backpropagator(Δ -> δx(Δ) * $∂₁f + δy(Δ) * $∂₂f)
                return Cassette.tag(f(x, y), ctx, back)
            end
        end
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
# ∇(f, x) = DynamicComputationGraphs.backward(f, x)[2](1.0)
# DynamicComputationGraphs.gradcheck(f, 1, ∇(h, 1))
