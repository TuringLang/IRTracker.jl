# import Cassette
using IRTools
using Core: CodeInfo, SlotNumber, SSAValue


const VariableMapping = Dict{IRTools.Variable, IRTools.Variable}

pushstatement!(ir, tape, stmt) = push!(ir, IRTools.xcall(Main, :push!, tape, stmt))


function track_branches!(new_block::IRTools.Block, old_block::IRTools.Block,
                         tape::IRTools.Variable, variable_mapping::VariableMapping)
    for branch in IRTools.branches(old_block)
        # apply variable renamings resulting from the shift by inserting statements
        renamed_args = [get!(variable_mapping, arg, arg) for arg in branch.args]
        
        if IRTools.isreturn(branch)
            # add tape to return values
            return_value = IRTools.push!(new_block, :(($tape, $(renamed_args...))))
            IRTools.return!(new_block, return_value)
        else
            IRTools.branch!(new_block, branch.block, renamed_args..., unless = branch.condition)
        end
    end

    return new_block
end


function track_statements!(new_block::IRTools.Block, old_block::IRTools.Block,
                           tape::IRTools.Variable, variable_mapping::VariableMapping)
    for (x, stmt) in old_block
        new_x = push!(new_block, stmt)
        push!(variable_mapping, x => new_x)
        call_expr = string(stmt.expr) # TODO actually quote this
        record = IRTools.xcall(DynamicComputationGraphs, :PrimitiveCall, call_expr, new_x)
        pushstatement!(new_block, tape, record)
    end

    return new_block
end


function track_first_block!(new_block::IRTools.Block, old_block::IRTools.Block,
                            variable_mapping::VariableMapping)
    # copy block arguments
    for arg in IRTools.arguments(old_block)
        IRTools.argument!(new_block, arg)
    end

    # set up tape variable
    tape = push!(new_block, IRTools.xcall(DynamicComputationGraphs, :GraphTape))

    # set up block arguments, record them as function arguments
    for arg in IRTools.arguments(new_block)
        # TODO actually quote this
        record = IRTools.xcall(DynamicComputationGraphs, :Argument, string(arg), arg)
        pushstatement!(new_block, tape, record)
    end

    track_statements!(new_block, old_block, tape, variable_mapping)
    track_branches!(new_block, old_block, tape, variable_mapping)
    return tape, new_block
end


function track_block!(new_block::IRTools.Block, old_block::IRTools.Block,
                      tape::IRTools.Variable, variable_mapping)
    # set up block arguments
    for arg in IRTools.arguments(old_block)
        IRTools.argument!(new_block, arg)
    end

    track_statements!(new_block, old_block, tape, variable_mapping)
    track_branches!(new_block, old_block, tape, variable_mapping)
    return new_block
end


function track_ir(old_ir)
    variable_mapping = VariableMapping()
    new_ir = empty(old_ir)

    # get first block (created by default), handle it, and store tape variable
    old_first_block = IRTools.block(old_ir, 1)
    new_first_block = IRTools.block(new_ir, 1)
    tape, first_block = track_first_block!(new_first_block, old_first_block, variable_mapping)

    # handle all other blocks
    for (i, old_block) in enumerate(IRTools.blocks(old_ir))
        i == 1 && continue # skip first block
        new_block = IRTools.block!(new_ir)
        track_block!(new_block, old_block, tape, variable_mapping)
    end

    return new_ir
end


IRTools.@dynamo function track(args...)
    ir = IRTools.IR(args...)
    new_ir = track_ir(ir)
    println(new_ir)
    println(ir)
    return ir
end


# https://github.com/MikeInnes/IRTools.jl/blob/b204489d143122c7508c202bb68181bd537fc798/src/ir/utils.jl#L12
# xcall(mod::Module, f::Symbol, args...) = Expr(:call, GlobalRef(mod, f), args...)
# xcall(f::Symbol, args...) = xcall(Base, f, args...)


# Cassette.@context DynamicGraphCtx

# # function Cassette.overdub(ctx::DynamicGraphCtx, f, args...)
# #     result, metadata = Cassette.recurse(ctx, f, args...), Expr(:call, nameof(f), args...)
# #     return result
# # end

# function insert_graph_tracker(::Type{<:DynamicGraphCtx}, reflection::Cassette.Reflection)
#     ci = reflection.code_info

#     # Cassette.insert_statements!(ci.code, ci.codelocs,
#     #                            (stmt, i) -> Meta.isexpr(stmt, :call) ? 2 : nothing,
#     #                             function (stmt, i)
#     #                                 return [stmt, Expr(:(=), SSAValue(1), xcall(Main, :println, "hi"))]
#     #                                # return [stmt, :(println($(Meta.quot(stmt))))]
#     #                            end)

#     println(reflection)

    
#     return ci
# end

# const graph_pass = Cassette.@pass insert_graph_tracker


# export track

# function track(f, args...)
#     tape = GraphTape()
#     ctx = Cassette.disablehooks(DynamicGraphCtx(pass = graph_pass, metadata = tape))
#     return Cassette.overdub(ctx, f, args...)
# end
