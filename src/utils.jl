using IRTools
import Base: getproperty

struct _DCGCall end
getproperty(::_DCGCall, name::Symbol) =
    (args...) -> IRTools.xcall(DynamicComputationGraphs, name, args...)

"""
`DCGCall.<bla>(args...)` is a hack to produce the properly `xcall`ed expression for
DynamicComputationGraphs.<bla>(args...).
"""
const DCGCall = _DCGCall()


macro coreshow(exs...)
    blk = Expr(:block)
    for ex in exs
        push!(blk.args, :(Core.println($(sprint(Base.show_unquoted, ex) * " = "),
                                       repr(begin value = $(esc(ex)) end))))
    end
    
    isempty(exs) || push!(blk.args, :value)
    
    return blk
end
