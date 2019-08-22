using IRTools
import Base: getproperty, getindex

struct _DCGCall end

const DCGCall = _DCGCall()
getproperty(::_DCGCall, name::Symbol) =
    (args...) -> IRTools.xcall(DynamicComputationGraphs, name, args...)


# Unique indexing into IR

abstract type IRIndex end

struct StmtIndex <: IRIndex
    varid::Int
end

struct BranchIndex <: IRIndex
    block::Int
    position::Int
end

getindex(ir::IRTools.IR, ix::StmtIndex) = ir[IRTools.var(ix.varid)]
getindex(ir::IRTools.IR, ix::BranchIndex) = IRTools.branches(ir, ix.block)[ix.position]
