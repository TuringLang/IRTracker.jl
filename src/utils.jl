using IRTools
import Base: getproperty

struct XCall
    var"#module#"::Module
end

function getproperty(x::XCall, name::Symbol)
    mod = getfield(x, Symbol("#module#"))
    if name === Symbol("#module#")
        return mod
    else
        return (args...; kwargs...) -> xcall_kw(mod, name, args...; kwargs...)
    end
end


"""
`IRTCall.<bla>(args...)` is a hack to produce the properly `xcall`ed expression for
IRTracker.<bla>(args...).
"""
const IRTCall = XCall(IRTracker)


function xcall_kw(_f::GlobalRef, args...; kwargs...)
    if isempty(kwargs)
        Expr(:call, _f, args...)
    else
        keys = QuoteNode[]
        values = Any[]
        for (k, v) in kwargs
            push!(keys, QuoteNode(k))
            push!(values, v)
        end

        _call(args...) = Expr(:call, args...)
        _apply_type = GlobalRef(Core, :apply_type)
        _NamedTuple = GlobalRef(Core, :NamedTuple)
        _tuple = GlobalRef(Core, :tuple)
        _kwfunc = GlobalRef(Core, :kwfunc)
        
        _namedtuple = _call(_apply_type, _NamedTuple, _call(_tuple, keys...))
        _kws = _call(_namedtuple, _call(_tuple, values...))
        return _call(_call(_kwfunc, _f), _kws, _f, args...)
    end
end

xcall_kw(mod::Module, f::Symbol, args...; kwargs...) =
    xcall_kw(GlobalRef(mod, f), args...; kwargs...)
xcall_kw(f::Symbol, args...; kwargs...) = xcall_kw(GlobalRef(Base, f), args...; kwargs...)



"""Equivalent of show without using the event loop (for usage in generated functions)."""
macro coreshow(exs...)
    blk = Expr(:block)
    for ex in exs
        push!(blk.args, :(Core.println($(sprint(Base.show_unquoted, ex) * " = "),
                                       repr(begin value = $(esc(ex)) end))))
    end
    
    isempty(exs) || push!(blk.args, :value)
    
    return blk
end



@generated function reified_ir(f, args...)
    # Since this is generated, it will generate the IR once per method and then return the literal
    # value inlined.
    return IRTools.IR(f, args...)
end


mutable struct Cached{T}
    value::Union{Nothing, Some{T}}

    Cached{T}() where {T} = new{T}(nothing)
    Cached(something::T) where {T} = new{T}(Some(something))
end

hasvalue(cached::Cached) = !isnothing(cached.value)
setvalue!(cached::Cached{T}, value) where {T} = (cached.value = Some(convert(T, value)); value)
getvalue(cached::Cached) = hasvalue(cached) ? cached.value.value : error("value not set")
getvalue!(cached::Cached{T}, value) where {T} = hasvalue(cached) ? getvalue(cached) : setvalue!(cached, value)
reset!(cached::Cached) = (cached.value = nothing)
