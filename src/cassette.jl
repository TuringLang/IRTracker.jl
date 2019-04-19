using Cassette

Cassette.@context TrackingCtx

mutable struct Tracker
    root::Union{Nothing, Call}
    parent::Union{Nothing, Call}
end

Tracker() = Tracker(nothing, nothing)


function Cassette.overdub(ctx::TrackingCtx, f, args...)
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
end


function track(f, args...)
    ctx = Cassette.disablehooks(TrackingCtx(metadata = Tracker()))
    r = Cassette.@overdub ctx f(args...)
    r, ctx.metadata.root
end
