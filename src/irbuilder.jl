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
