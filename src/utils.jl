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


"""
Unique index to a certain position in IR code; either to a variable, given by block and number,
or to a branch, given by block and position among all branches.
"""
abstract type IRIndex end

struct VarIndex <: IRIndex
    block::Int
    id::Int
end

struct BranchIndex <: IRIndex
    block::Int
    id::Int
end

getindex(ir::IR, ix::VarIndex) = ir[IRTools.var(ix.id)]
getindex(ir::IR, ix::BranchIndex) = IRTools.branches(ir, ix.block)[ix.position]


"""Convert an expression into an expression that will evaluate to that expression, quoted literally."""
reify_quote(expr) = Expr(:copyast, QuoteNode(expr))

