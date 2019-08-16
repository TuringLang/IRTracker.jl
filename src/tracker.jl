# import Cassette
using IRTools
using Core: CodeInfo, SlotNumber, SSAValue
import IRTools: pushfirst!
using InteractiveUtils: typesof



struct TrackerResult{isprimitive}
    value
    children
end

TrackerResult(value) = TrackerResult{PrimitiveCall}(value, nothing)
TrackerResult(value, children) = TrackerResult{NestedCall}(value, children)

record!(tape::GraphTape, expr, result::TrackerResult{PrimitiveCall}) =
    push!(tape, PrimitiveCall(expr, result.value))
record!(tape::GraphTape, expr, result::TrackerResult{NestedCall}) =
    push!(tape, NestedCall(expr, result.value, result.children))
record!(tape::GraphTape, result::Union{Constant, Argument}) =
    push!(tape, result)



function update_returns!(block::IRTools.Block, tape)
    # called only from within a non-primitive call
    for branch in IRTools.branches(block)
        if IRTools.isreturn(branch)
            return_arg = branch.args[1]
            tracker_result_expr = IRTools.xcall(DynamicComputationGraphs, :TrackerResult,
                                                return_arg, tape)
            tracker_result_value = IRTools.push!(block, tracker_result_expr)
            return_expr = IRTools.xcall(:tuple, return_arg, tracker_result_value)
            return_value = IRTools.push!(block, return_expr)
            IRTools.return!(block, return_value)
        end
    end

    return block
end


function track_statement!(p::IRTools.Pipe, tape, variable, statement)
    if Meta.isexpr(statement.expr, :call)
        recursive_expr = IRTools.xcall(DynamicComputationGraphs, :_track, statement.expr.args...)
        recursive_value = IRTools.insert!(p, variable, recursive_expr)
        p[variable] = IRTools.xcall(:getfield, recursive_value, 1)
        tracking_result = IRTools.push!(p, IRTools.xcall(:getfield, recursive_value, 2))
        
        tracked_stmt = string(statement.expr)
        stmt_record = IRTools.xcall(DynamicComputationGraphs, :record!, tape,
                                    tracked_stmt, tracking_result)
        IRTools.push!(p, stmt_record)
    elseif statement.expr isa QuoteNode
       # for statements that are just constants (like type literals, which become QuoteNodes)
        tracked_expr = IRTools.xcall(DynamicComputationGraphs, :Constant, variable)
        stmt_record = IRTools.xcall(DynamicComputationGraphs, :record!, tape, tracked_expr)
        IRTools.push!(p, stmt_record)
    end
    
    return nothing
end


function track_arguments!(p::IRTools.Pipe, tape, arguments)
    for arg in arguments
        arg === tape && continue
        arg_expr = IRTools.xcall(DynamicComputationGraphs, :Argument, arg.id, arg)
        arg_record = IRTools.xcall(DynamicComputationGraphs, :record!, tape, arg_expr)
        IRTools.push!(p, arg_record)
    end

    return nothing
end


function track_ir(old_ir::IRTools.IR)
    p = IRTools.Pipe(old_ir)
    tape = IRTools.push!(p, IRTools.xcall(DynamicComputationGraphs, :GraphTape))
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


function track_primitive(F, args)
    # primitives (i.e., builtin functions) have no IR, so they are converted to wrapped methods,
    # which do the same thing, but track a PrimitiveCall without recursion.
    
    
    f = Core.Compiler.singleton_type(F)
    mod = Core.Compiler.typename(F).module
    T = Tuple{args...}
    dummy(args...) = nothing
    ir = empty(IRTools.IR(IRTools.meta(Tuple{typeof(dummy), Core.Typeof.(args)...})))
    self = IRTools.argument!(ir)
    
    for arg in args
        IRTools.argument!(ir)
    end
    
    primitive_expr = IRTools.xcall(mod, nameof(f), IRTools.arguments(ir)[2:end]...)
    primitive_value = IRTools.push!(ir, primitive_expr)

    tracked_expr = IRTools.xcall(DynamicComputationGraphs, :TrackerResult, primitive_value)
    tracked_value = IRTools.push!(ir, tracked_expr)

    return_expr = IRTools.xcall(:tuple, primitive_value, tracked_value)
    return_value = IRTools.push!(ir, return_expr)
    IRTools.return!(ir, return_value)
    
    return ir
end




export track

IRTools.@dynamo function _track(F, args...)
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    f = Core.Compiler.singleton_type(F)
    mod = Core.Compiler.typename(F).module
    is_builtin = ((f isa Core.Builtin) && !(mod === Core.Compiler))
    
    if !is_builtin
        println("handling $F with args $args")
        ir = IRTools.IR(F, args...)
        new_ir = track_ir(ir)
        # @show ir
        @show new_ir
        return new_ir
    else
        println("handling primitive $F with args $args")
        new_ir = track_primitive(F, args)
        @show new_ir
        return new_ir
    end
end

function track(F, args...)
    result = _track(F, args...)
    return result
end


# @generated function track(f, args...)
#     ir = track_ir(IRTools.IR(f, args...))
#     println(ir)

#     m = ir.meta::IRTools.Meta
#     ir = IRTools.varargs!(m, ir)
#     IRTools.argnames!(m, :args)
#     _self = IRTools.splicearg!(m, ir, Symbol("#self#"))
#     IRTools.prewalk!(x -> x === IRTools.self ? _self : x, ir)
#     return IRTools.update!(m.code, ir)
# end



# @generated function test1(f, args...)
#     ir = IRTools.empty(IRTools.IR(f, args...))
#     push!(ir, IRTools.xcall(Main, :println, "hi"))
#     IRTools.return!(ir, nothing)

#     m = ir.meta::IRTools.Meta
#     ir = IRTools.varargs!(m, ir)
#     IRTools.argnames!(m, :args)
#     _self = IRTools.splicearg!(m, ir, Symbol("#self#"))
#     IRTools.prewalk!(x -> x === IRTools.self ? _self : x, ir)
#     return IRTools.update!(m.code, ir)
# end



