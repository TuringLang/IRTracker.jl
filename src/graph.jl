using IRTools
import Base: getindex


"""
Unique index to a certain position in IR code; either to a variable, given by block and number,
or to a branch, given by block and position among all branches.
"""
abstract type IRIndex end

struct VarIndex <: IRIndex
    block::Int
    line::Int
end

struct BranchIndex <: IRIndex
    block::Int
    line::Int
end

struct NoIndex <: IRIndex end
const NO_INDEX = NoIndex()

getindex(ir::IRTools.IR, ix::VarIndex) = ir[IRTools.var(ix.line)]
getindex(ir::IRTools.IR, ix::BranchIndex) = IRTools.branches(ir, ix.block)[ix.line]
getindex(ir::IRTools.IR, ix::NoIndex) = throw(DomainError(ix, "Can't use `NoIndex` as an IR index!"))


# we need this forward declaration here, because mutually recursive types are not possible (yet...)

"""Node in a `GraphTape`.  Represents statements or branches in tracked IR."""
abstract type AbstractNode end

"""Representats a SSA statement in tracked IR in a `GraphTape`."""
abstract type DataFlowNode{T} <: AbstractNode end

abstract type RecursiveNode{T} <: DataFlowNode{T} end

"""Representats a branch in tracked IR in a `GraphTape`."""
abstract type ControlFlowNode <: AbstractNode end


const NullableRef{T} = Ref{Union{T, Nothing}}
NullableRef{T}() where {T} = Ref{Union{T, Nothing}}(nothing)

const ArgumentTuple{T} = Tuple{Vararg{T}}


include("tapeexpr.jl")

include("nodeinfo.jl")

include("nodes.jl")

include("graphapi.jl")
