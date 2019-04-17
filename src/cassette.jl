using Cassette

Cassette.@context TrackingCtx

mutable struct Tracker
    isfirst::Bool
    current::Union{Nothing, Call}
    stack::Vector{Call}
    Tracker() = new(true, nothing, Call[])
end

function enter!(t::Tracker, f, args)
    call = Call(f, args)
    if !t.isfirst
        push!(t.current.body, call)
        push!(t.stack, t.current)
        t.current = call
    else
        t.current = call
        push!(t.stack, t.current)
        t.isfirst = false
    end
    return nothing
end

function exit!(t::Tracker, output, f, args)
    t.current = pop!(t.stack)
    return nothing
end

Cassette.prehook(ctx::TrackingCtx, f, args...) = enter!(ctx.metadata, f, args)
Cassette.posthook(ctx::TrackingCtx, output, f, args...) = exit!(ctx.metadata, output, f, args)

# function Cassette.overdub(ctx::TrackingCtx, first::Val{true}, f, args...)
#     if Cassette.canrecurse(ctx, f, args...)
#         _ctx = Cassette.similarcontext(ctx, metadata = callback)
#         return Cassette.recurse(_ctx, f, args...) # return result, callback
#     else
#         return Cassette.fallback(ctx, f, args...), callback
#     end
# end

function track(f, args...)
    ctx = TrackingCtx(metadata = Tracker())
    r = Cassette.overdub(ctx, () -> f(args...))
    r, ctx.metadata.current
end
