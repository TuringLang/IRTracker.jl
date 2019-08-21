using IRTools: xcall
import Base: getproperty

struct _DCGCall end

const DCGCall = _DCGCall()
getproperty(::_DCGCall, name::Symbol) = (args...) -> xcall(DynamicComputationGraphs, name, args...)
