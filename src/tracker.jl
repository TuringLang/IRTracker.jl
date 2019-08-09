import Cassette
# using IRTools
using Core: CodeInfo, SlotNumber, SSAValue

function instructions(block::IRTools.BasicBlock)
    return [getfield.(block.stmts, :expr); block.branches]
end

function instructions(ir::IRTools.IR)
    mapreduce(instructions, vcat, ir.blocks)
end


IRTools.@dynamo function track(args...)
    ir = IRTools.IR(args...)
    new_ir = IRTools.IR()

    trace = IRTools.argument!(new_ir)
    ssa_mappings = Dict{IRTools.Variable, IRTools.Variable}()

    for block in IRTools.blocks(ir)
        if block.id ∉ axes(new_ir.blocks, 1)
            new_block = IRTools.block!(new_ir)
        else
            new_block = IRTools.block(new_ir, block.id)
        end

        for arg in IRTools.arguments(block)
            IRTools.argument!(new_block, arg)
            arg === trace && continue
            record = IRTools.xcall(DynamicComputationGraphs, :Argument, string(arg), arg)
            push!(new_block, IRTools.xcall(Main, :push!, trace, record))
        end
        
        for (x, stmt) in block
            new_x = push!(new_block, stmt)
            push!(ssa_mappings, x => new_x)
            call_expr = string(stmt.expr) # TODO actually quote this
            record = IRTools.xcall(DynamicComputationGraphs, :PrimitiveCall, call_expr, new_x)
            push!(new_block, IRTools.xcall(Main, :push!, trace, record))
        end

        for branch in IRTools.branches(block)
            new_args = [get!(ssa_mappings, arg, arg) for arg in branch.args]
            IRTools.branch!(new_block, branch.block, new_args..., unless = branch.condition)
        end
    end

    println(new_ir)
    
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
