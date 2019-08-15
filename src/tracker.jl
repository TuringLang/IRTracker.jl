# import Cassette
using IRTools
using Core: CodeInfo, SlotNumber, SSAValue
import IRTools: pushfirst!
using InteractiveUtils: typesof


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
    if Meta.isexpr(statement.expr, :call)
        tracking_stmt = IRTools.xcall(DynamicComputationGraphs, :track, statement.expr.args...)
        tracking_result = IRTools.insert!(p, variable, tracking_stmt)
        p[variable] = IRTools.xcall(:getfield, tracking_result, 1)
        subgraph = IRTools.push!(p, IRTools.xcall(:getfield, tracking_result, 2))
        
        tracked_expr = IRTools.xcall(DynamicComputationGraphs, :NestedCall,
                                     string(statement.expr),
                                     variable, subgraph)
        stmt_record = IRTools.xcall(:push!, tape, tracked_expr)
        IRTools.push!(p, stmt_record)
    elseif statement.expr isa QuoteNode
       # for statements that are just constants (like type literals, which become QuoteNodes)
        tracked_expr = IRTools.xcall(DynamicComputationGraphs, :Constant, variable)
        stmt_record = IRTools.xcall(:push!, tape, tracked_expr)
        IRTools.push!(p, stmt_record)
    end
    
    return nothing
end


function track_arguments!(p::IRTools.Pipe, tape, arguments)
    for arg in arguments
        arg === tape && continue
        arg_expr = IRTools.xcall(DynamicComputationGraphs, :Argument, arg.id, arg)
        arg_record = IRTools.xcall(:push!, tape, arg_expr)
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
    
    tape = IRTools.push!(ir, IRTools.xcall(DynamicComputationGraphs, :GraphTape))
    primitive_expr = IRTools.xcall(mod, nameof(f), IRTools.arguments(ir)[2:end]...)
    primitive_result = push!(ir, primitive_expr)

    tracked_expr = IRTools.xcall(DynamicComputationGraphs, :PrimitiveCall,
                                 string(primitive_expr),
                                 primitive_result)
    stmt_record = IRTools.xcall(:push!, tape, tracked_expr)
    push!(ir, stmt_record)

    return_expr = IRTools.xcall(:tuple, primitive_result, tape)
    return_value = IRTools.push!(ir, return_expr)
    IRTools.return!(ir, return_value)
    
    return ir
end


export track

IRTools.@dynamo function track(F, args...)
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    is_builtin = ((F <: Core.Builtin) && !(Core.Compiler.typename(F).module === Core.Compiler))
    
    if !is_builtin
        ir = IRTools.IR(F, args...)
        println("handling $F with args $args")
        new_ir = track_ir(ir)
        println(new_ir)
        return new_ir
    else
        ir = track_primitive(F, args)
        println("handling primitive $F with args $args")
        println(ir)
        return ir
    end
end



# function track(f, args...)
#     tape = GraphTape()
#     return _track(f, args..., tape)
# end

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



