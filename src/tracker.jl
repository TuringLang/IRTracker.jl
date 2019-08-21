using IRTools
import IRTools: pushfirst!


struct TrackerResult{T}
    value
    children
end

TrackerResult(value) = TrackerResult{PrimitiveCall}(value, nothing)
TrackerResult(value, children) = TrackerResult{NestedCall}(value, children)


record!(tape::GraphTape, value::Union{Constant, Argument}) =
    push!(tape, value)

function record!(tape::GraphTape, expr, f::F, args...) where F
    # TODO: make this generated!

    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    mod = Core.Compiler.typename(F).module
    is_builtin = ((F <: Core.Builtin) && !(mod === Core.Compiler))

    if is_builtin
        result = f(args...)
        call = PrimitiveCall(expr, result)
        push!(tape, call)
        return result
    else
        result, children = track(f, args...)
        call = NestedCall(expr, result, children)
        push!(tape, call)
        return result
    end
end


function update_returns!(block::IRTools.Block, tape)
    # called only from within a non-primitive call
    for branch in IRTools.branches(block)
        if IRTools.isreturn(branch)
            return_arg = branch.args[1]
            return_expr = IRTools.xcall(:tuple, return_arg, tape)
            return_value = IRTools.push!(block, return_expr)
            IRTools.return!(block, return_value)
        end
    end

    return block
end


function track_statement!(p::IRTools.Pipe, tape, variable, statement)
    if Meta.isexpr(statement.expr, :call)
        reified_call = string(statement.expr)
        p[variable] = DCGCall.record!(tape, reified_call, statement.expr.args...)
        # p[variable] = IRTools.xcall(DynamicComputationGraphs, :record, reified_call,
                                    # statement.expr.head, statement.expr.args...)
    elseif statement.expr isa QuoteNode
        # for statements that are just constants (like type literals)
        constant_expr = DCGCall.Constant(variable)
        constant_record = DCGCall.record!(tape, constant_expr)
        # constant_expr = IRTools.xcall(DynamicComputationGraphs, :Constant, variable)
        # constant_record = IRTools.xcall(DynamicComputationGraphs, :record!, tape, constant_expr)
        IRTools.push!(p, constant_record)
    else
        # other special things, like `Expr(:boundscheck)`
        # currently unhandled and simply kept
    end
    
    return nothing
end


function track_arguments!(p::IRTools.Pipe, tape, arguments)
    for argument in arguments
        argument === tape && continue
        argument_expr = DCGCall.Argument(argument.id, argument)
        argument_record = DCGCall.record!(tape, argument_expr)
        # argument_expr = IRTools.xcall(DynamicComputationGraphs, :Argument, argument.id, argument)
        # argument_record = IRTools.xcall(DynamicComputationGraphs, :record!, tape, argument_expr)
        IRTools.push!(p, argument_record)
    end

    return nothing
end


function track_ir(old_ir::IRTools.IR)
    p = IRTools.Pipe(old_ir)
    tape = push!(p, DCGCall.GraphTape())
    # tape = IRTools.push!(p, IRTools.xcall(DynamicComputationGraphs, :GraphTape))
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


# function track_builtin(stmt, F, args)
#     # builtin functions have no IR, so they are converted to wrapped methods,
#     # which do the same thing, but track a PrimitiveCall without recursion.

#     f = Core.Compiler.singleton_type(F)
#     mod = Core.Compiler.typename(F).module
#     dummy(args...) = nothing
#     new_ir = empty(IRTools.IR(IRTools.meta(Tuple{typeof(dummy), Core.Typeof.(args)...})))
#     self = IRTools.argument!(new_ir)
    
#     for arg in args
#         IRTools.argument!(new_ir)
#     end
    
#     builtin_expr = IRTools.xcall(mod, nameof(f), IRTools.arguments(new_ir)[2:end]...)
#     builtin_value = IRTools.push!(new_ir, builtin_expr)

#     tracked_expr = IRTools.xcall(DynamicComputationGraphs, :TrackerResult, builtin_value)
#     tracked_value = IRTools.push!(new_ir, tracked_expr)

#     return_expr = IRTools.xcall(:tuple, builtin_value, tracked_value)
#     return_value = IRTools.push!(new_ir, return_expr)
#     IRTools.return!(new_ir, return_value)
    
#     return new_ir
# end




export track

IRTools.@dynamo function track(F, args...)
    println("handling $F with args $args")
    ir = IRTools.IR(F, args...)
    if isnothing(ir)
        @error "You probably tried tracking a builting function: $F"
    end
    
    new_ir = track_ir(ir)
    # @show ir
    @show new_ir
    return new_ir
end


# macro track(expr)
#     isexpr(expr, :call) || error("Expression not in the form @track f(args...)")
#     f, args = ex.args[1], ex.args[2:end]
#     :(_track($(Meta.quot(expr)), $(esc.((f, args...))...)))
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



