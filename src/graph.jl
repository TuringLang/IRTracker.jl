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

getindex(ir::IRTools.IR, ix::VarIndex) = ir[IRTools.var(ix.line)]
getindex(ir::IRTools.IR, ix::BranchIndex) = IRTools.branches(ir, ix.block)[ix.line]


# we need this forward declaration here, because mutually recursive types are not possible (yet...)

"""Node in a `GraphTape`.  Represents statements or branches in tracked IR."""
abstract type Node end

"""Representats a SSA statement in tracked IR in a `GraphTape`."""
abstract type StatementNode <: Node end

"""Representats a branch in tracked IR in a `GraphTape`."""
abstract type BranchNode <: Node end


include("graphtape.jl")

include("tapeexpr.jl")

include("nodes.jl")
