import Base: (==)

tracker(x) = nothing

istracked(x) = tracker(x) ≠ nothing
isleaf(x) = !istracked(x) || isleaf(tracker(x))
grad(x) = grad(tracker(x))
grad(::Nothing) = nothing
data(x) = x


mutable struct Tracker{G}
    ref::UInt32
    f::Call
    isleaf::Bool
    grad::G
    
    Tracker{G}(f::Call) where G = new(0, f, false)
    Tracker{G}(f::Call, grad::G) where G = new(0, f, false, grad)
    Tracker{G}(f::Call{Nothing}, grad::G) where G = new(0, f, true, grad)
end

istracked(x::Tracker) = true
isleaf(x::Tracker) = x.f == Call()
grad(x::Tracker) = x.grad

track(f::Call, x) = Tracker{typeof(x)}(f)


mutable struct Tracked{T, N, G}
    data::T
    tracker::Tracked{G}

    Tracked(data::T) where {T} = new{T, 0, T}(data, Tracker{T}())
    Tracked(data::AbstractArray{T, N}) where {T,N} = new{T, N, Array{T, N}}
end


function _forward end

function track(f::F, xs...; kw...) where F
    y, back = _forward(f, xs...; kw...)
    track(Call(back, tracker.(xs)), y)
end


function forward(f, ps::Params)
    y = f()
    y, function (Δ)
        g = Grads(ps)
        if istracked(y)
            scan(y)
            back(g, tracker(y), Δ)
        end
        return g
    end
end

function forward(f, args...)
    args = param.(args)
    y, back = forward(() -> f(args...), Params(args))
    y, Δ -> getindex.(Ref(back(Δ)), args)
end
