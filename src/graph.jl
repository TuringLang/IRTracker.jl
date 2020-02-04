using IRTools
import Base: getindex


"""
    IRIndex

Abstract supertype for unique indices to a certain position in IR code; either to a variable, given
by block and number ([`VarIndex`](@ref)), or to a branch, given by block and position among all branches
([`BranchIndex`](@ref)).
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

"""Abstract supertype for all nodes in a `GraphTape`.  Represents statements or branches in tracked IR."""
abstract type AbstractNode end

"""
    DataFlowNode{T}

Abstract supertype for nodes that track SSA statements in IR.  `T` is the type of the value of the
statement.
"""
abstract type DataFlowNode{T} <: AbstractNode end

abstract type RecursiveNode{T} <: DataFlowNode{T} end

"""Represents a branch in tracked IR in a `GraphTape`."""
abstract type ControlFlowNode <: AbstractNode end


const NullableRef{T} = Ref{Union{T, Nothing}}
NullableRef{T}() where {T} = Ref{Union{T, Nothing}}(nothing)

const ArgumentTuple{T} = Tuple{Vararg{T}}


include("tapeexpr.jl")

include("nodeinfo.jl")

include("nodes.jl")

include("graphapi.jl")
