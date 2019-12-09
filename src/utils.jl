using IRTools
import Base: getproperty

struct _DCGCall end
function getproperty(::_DCGCall, name::Symbol)
    return (args...; kwargs...) -> xcall_kw(DynamicComputationGraphs, name, args...; kwargs...)
end

"""
`DCGCall.<bla>(args...)` is a hack to produce the properly `xcall`ed expression for
DynamicComputationGraphs.<bla>(args...).
"""
const DCGCall = _DCGCall()


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



function xcall_kw(_f, args...; kwargs...)
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
