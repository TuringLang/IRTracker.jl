# import Cassette
using IRTools
using Core: CodeInfo, SlotNumber, SSAValue
import IRTools: pushfirst!


function pushfirst!(p::IRTools.Pipe, x)
    tmp = IRTools.var!(p)
    inner_pushed = IRTools.pushfirst!(p.to, IRTools.prewalk(IRTools.substitute(p), x))
    IRTools.substitute!(p, tmp, inner_pushed)
    return tmp
end


function update_returns!(block::IRTools.Block, tape)
    for branch in IRTools.branches(block)
        if IRTools.isreturn(branch)
            return_expr = IRTools.xcall(:tuple, branch.args..., tape)
            return_value = IRTools.push!(block, return_expr)
            IRTools.return!(block, return_value)
        end
    end

    return block
end


function track_statement!(p::IRTools.Pipe, tape, variable, statement)
    original_expr = QuoteNode(statement.expr)
    tracked_expr = IRTools.xcall(DynamicComputationGraphs, :PrimitiveCall, original_expr, variable)
    stmt_record = IRTools.xcall(:push!, tape, tracked_expr)
    return IRTools.insertafter!(p, variable, stmt_record)
end


function track_arguments!(p::IRTools.Pipe, tape, arguments)
    previous_stmt = tape
    for arg in reverse(arguments)
        arg === tape && continue
        arg_expr = IRTools.xcall(DynamicComputationGraphs, :Argument, arg.id, arg)
        arg_record = IRTools.xcall(:push!, tape, arg_expr)
        previous_stmt = IRTools.insertafter!(p, previous_stmt, arg_record)
    end
end


function add_tape_argument!(p::IRTools.Pipe, tape)
    tape = IRTools.argument!(p)
end


function track_ir(old_ir::IRTools.IR)
    p = IRTools.Pipe(old_ir)
    tape = IRTools.pushfirst!(p, IRTools.xcall(DynamicComputationGraphs, :GraphTape))
    track_arguments!(p, tape, IRTools.arguments(old_ir))
    
    for (v, stmt) in p
        track_statement!(p, tape, v, stmt)
    end
    
    new_ir = IRTools.finish(p)

    # update all return values to include `tape`
    for block in IRTools.blocks(new_ir)
        update_returns!(block, IRTools.substitute(p, tape))
    end

    return new_ir
end



export track

# IRTools.@dynamo function track(f, args...)
#     ir = IRTools.IR(f, args...)
#     new_ir = track_ir(ir)
#     println(new_ir)

#     return new_ir
# end

@generated function track(f, args...)
    ir = track_ir(IRTools.IR(f, args...))
    println(ir)

    m = ir.meta::IRTools.Meta
    ir = IRTools.varargs!(m, ir)
    IRTools.argnames!(m, :args)
    _self = IRTools.splicearg!(m, ir, Symbol("#self#"))
    IRTools.prewalk!(x -> x === IRTools.self ? _self : x, ir)
    return IRTools.update!(m.code, ir)
end

# function track(f, args...)
#     tape = GraphTape()
#     return _track(f, args..., tape)
# end

@generated function test1(f, args...)
    ir = IRTools.empty(IRTools.IR(f, args...))
    push!(ir, IRTools.xcall(Main, :println, "hi"))
    IRTools.return!(ir, nothing)

    m = ir.meta::IRTools.Meta
    ir = IRTools.varargs!(m, ir)
    IRTools.argnames!(m, :args)
    _self = IRTools.splicearg!(m, ir, Symbol("#self#"))
    IRTools.prewalk!(x -> x === IRTools.self ? _self : x, ir)
    return IRTools.update!(m.code, ir)
end



