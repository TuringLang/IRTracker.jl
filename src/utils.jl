using IRTools
import Base: getproperty, getindex

struct _DCGCall end

const DCGCall = _DCGCall()
getproperty(::_DCGCall, name::Symbol) =
    (args...) -> IRTools.xcall(DynamicComputationGraphs, name, args...)


# Unique indexing into IR

abstract type IRIndex end

struct VarIndex <: IRIndex
    block::Int
    id::Int
end

struct BranchIndex <: IRIndex
    block::Int
    id::Int
end

getindex(ir::IRTools.IR, ix::VarIndex) = ir[IRTools.var(ix.id)]
getindex(ir::IRTools.IR, ix::BranchIndex) = IRTools.branches(ir, ix.block)[ix.position]



function print_intrinsic_error(f::Core.IntrinsicFunction, args...)
    # from https://github.com/JuliaLang/julia/blob/c6da87ff4bc7a855e217856757ad3413cf6d1f79/base/show.jl#L398
    name = unsafe_string(ccall(:jl_intrinsic_name, Cstring, (Core.IntrinsicFunction,), f))
    error("Can't track the intrinsic function ", name, " with arguments ",
          join(args, ", "))
end



struct TapeIndex
    id::Int
end

reify_quote(expr) = Expr(:copyast, QuoteNode(expr))


struct VariableMap
    map::Dict{Any, Any}
end

VariableMap() = VariableMap(Dict{Any, Any}())

# substitute(vm::VariableMap, x::Union{IRTools.Variable, IRTools.NewVariable}) = vm.map[x]
substitute(vm::VariableMap, x) = get(vm.map, x, x)
substitute(vm::VariableMap) = x -> substitute(vm, x)

record_substitution!(vm::VariableMap, x, y) = push!(vm.map, x => y)


const JumpTargets = Dict{Int, Vector{Int}}

function pushtarget!(jt::JumpTargets, from, to)
    t = get!(jt, to, Int[])
    push!(t, from)
end

function jumptargets(ir::IRTools.IR)
    targets = JumpTargets()
    
    for block in IRTools.blocks(ir)
        branches = IRTools.branches(block)
        
        for (i, branch) in enumerate(branches)
            if !IRTools.isreturn(branch)
                pushtarget!(targets, block.id, branch.block)

                if IRTools.isconditional(branch) && i == length(branches)
                    # conditional branch with fallthrough (last of all)
                    pushtarget!(targets, block.id, block.id + 1)
                end
            end
        end
    end

    return targets
end

