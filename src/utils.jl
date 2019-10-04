using IRTools
using IRTools: IR
import Base: getproperty, getindex

struct _DCGCall end
getproperty(::_DCGCall, name::Symbol) =
    (args...) -> IRTools.xcall(DynamicComputationGraphs, name, args...)

"""
`DCGCall.<bla>(args...)` is a hack to produce the properly `xcall`ed expression for
DynamicComputationGraphs.<bla>(args...).
"""
const DCGCall = _DCGCall()


"""Convert an expression into an expression that will evaluate to that expression, quoted literally."""
reify_quote(expr) = Expr(:copyast, QuoteNode(expr))

