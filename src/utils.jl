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


"""
Special handling to get the name of the intrinsic function `f` and print an error message that it 
can't be tracked.
"""
function print_intrinsic_error(f::Core.IntrinsicFunction, args...)
    # from https://github.com/JuliaLang/julia/blob/c6da87ff4bc7a855e217856757ad3413cf6d1f79/base/show.jl#L398
    name = unsafe_string(ccall(:jl_intrinsic_name, Cstring, (Core.IntrinsicFunction,), f))
    error("Can't track the intrinsic function ", name, " with arguments ",
          join(args, ", "))
end


"""Convert an expression into an expression that will evaluate to that expression, quoted literally."""
reify_quote(expr) = Expr(:copyast, QuoteNode(expr))

