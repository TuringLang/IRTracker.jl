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

