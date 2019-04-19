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


function forward(f, x)
    ctx = Cassette.enabletagging(FDiffCtx(), f)
    r = Cassette.overdub(ctx, f, Cassette.tag(x, ctx, oftype(x, 1.0)))
    Cassette.untag(r, ctx), tangent(r, ctx)
end


for (M, f, arity) in DiffRules.diffrules()
    M == :Base || continue

    # x = ntuple(i -> Symbol(:x, i), arity)
    # dfdx = DiffRules.diffrule.(M, f, vars...)

    # tx = [Symbol(:t, xᵢ) for xᵢ in x]
    # untaggins = [:(Cassette.untag($txᵢ, ctx)) for txᵢ in tx]
    # dx = [Symbol(:d, xᵢ) for xᵢ in x]
    # tangents = [:(tangent($txᵢ, ctx)) for txᵢ in tx]
    # dotproduct = foldr(map((dfdxᵢ, dxᵢ) -> :(dfdxᵢ * dxᵢ), dfdx, dx)) do product, rest
    #     :($rest + $product)
    # end
    
    # @eval begin
    #     function Cassette.overdub(ctx::FDiffCtx, f::typeof($f), $(inputs...)) where
    #         $(x...) = $(untaggings...)
    #         $(dx...) = $(tangents...)
    #         return Cassette.tag(f($(x...)), ctx, dotproduct)
    #     end
    # end
    
    if arity == 1
        dfdx = DiffRules.diffrule(M, f, :x)
        
        @eval begin
            function Cassette.overdub(ctx::FDiffCtx{T}, f::typeof($f), tx) where {T}
                x = Cassette.untag(tx, ctx)
                dx = tangent(tx, ctx)
                return Cassette.tag(f(x), ctx, $dfdx * dx)
            end
        end
    elseif arity == 2
        dfdx, dfdy = DiffRules.diffrule(M, f, :x, :y)
        
        @eval begin
            function Cassette.overdub(ctx::FDiffCtx, f::typeof($f), tx, ty)
                x, y = Cassette.untag(tx, ctx), Cassette.untag(ty, ctx)
                dx, dy = tangent(tx, ctx), tangent(ty, ctx)
                return Cassette.tag(f(x, y), ctx, $dfdx * dx + $dfdy * dy)
            end
        end
    end
end

