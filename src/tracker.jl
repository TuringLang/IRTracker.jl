# import Cassette
using IRTools
using Core: CodeInfo, SlotNumber, SSAValue
import IRTools: pushfirst!


function pushfirst!(p::IRTools.Pipe, x)
    first_v, first_stmt = first(p)
    IRTools.insert!(p, first_v, x)
end


function track_ir(old_ir::IRTools.IR)
    p = IRTools.Pipe(old_ir)
    tape = IRTools.pushfirst!(p, IRTools.xcall(DynamicComputationGraphs, :GraphTape))
    
    for (i, (v, stmt)) in enumerate(p)
        # first, record original arguments (_not_ `tape`!)
        if i == 1
            first_v = v
            
            for arg in reverse(IRTools.arguments(old_ir))
                arg === tape && continue
                arg_record = IRTools.xcall(:push!, tape,
                                           IRTools.xcall(DynamicComputationGraphs, :Argument, arg.id, arg))
                first_v = IRTools.insert!(p, first_v, arg_record)
            end
        end
        
        call_expr = QuoteNode(stmt.expr)
        stmt_record = IRTools.xcall(:push!, tape, 
                                    IRTools.xcall(DynamicComputationGraphs, :PrimitiveCall, call_expr, v))
        IRTools.insertafter!(p, v, stmt_record)
    end

    new_ir = IRTools.finish(p)

    # update return values to include `tape`
    for block in IRTools.blocks(new_ir)
        for branch in IRTools.branches(block)
            if IRTools.isreturn(branch)
                return_value = IRTools.push!(block,
                                             IRTools.xcall(:tuple, branch.args...,
                                                           IRTools.substitute(p, tape)))
                IRTools.return!(block, return_value)
            end
        end
    end

    return new_ir
end



export track

IRTools.@dynamo function track(args...)
    ir = IRTools.IR(args...)
    new_ir = track_ir(ir)
    println(new_ir)

    return new_ir
end

# function track(f, args...)
#     tape = GraphTape()
#     return _track(f, args..., tape)
# end

