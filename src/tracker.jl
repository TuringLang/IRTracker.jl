import Cassette
using IRTools


IRTools.@dynamo function track(args...)
    ir = IRTools.IR(args...)
    
    for x in reverse(eachindex(ir))
        IRTools.insertafter!(ir, x, ir[x])
    end
    
    for block in blocks(ir)
        if isreturn(block.branches[end])
            block.branches[end].args[1] = block.statements[end]
        end
    end
    
    return ir
end

# Cassette.@context DynamicGraphCtx

# # function Cassette.overdub(ctx::DynamicGraphCtx, f, args...)
# #     result, metadata = Cassette.recurse(ctx, f, args...), Expr(:call, nameof(f), args...)
# #     return result
# # end

# function insert_graph_tracker(::Type{<:DynamicGraphCtx}, reflection::Cassette.Reflection)
#     ci = reflection.code_info
#     ir = IRTools.IR(ci, reflection.method.nargs)

#     Cassette.insert_statements!(ir.code, ir.codelocs,
#                                (stmt, i) -> Meta.isexpr(stmt, :call) ? 2 : nothing,
#                                 function (stmt, i)
#                                     println(stmt)
#                                     return [:(println("hi")), stmt]
#                                    # return [stmt, :(println($(Meta.quot(stmt))))]
#                                end)
#     # for i in reverse(eachindex(ir.code))
#     #     expr = ir[i].expr
#     #     IRTools.insertafter!(ir, i, :(println($(Meta.quot(expr)))))
#     # end
    
#     return ir
# end

# const graph_pass = Cassette.@pass insert_graph_tracker


# export track

# function track(f, args...)
#     tape = GraphTape()
#     ctx = Cassette.disablehooks(DynamicGraphCtx(pass = graph_pass, metadata = tape))
#     return Cassette.overdub(ctx, f, args...)
# end
