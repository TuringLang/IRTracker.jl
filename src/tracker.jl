using IRTools
import IRTools: pushfirst!


struct TrackerResult{T}
    value
    children
end

TrackerResult(value) = TrackerResult{PrimitiveCall}(value, nothing)
TrackerResult(value, children) = TrackerResult{NestedCall}(value, children)


record!(tape::GraphTape, value::Union{Constant, Argument, Return}) =
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
            reified_return_arg = string(return_arg)

            return_record = DCGCall.record!(tape, DCGCall.Return(reified_return_arg, return_arg))
            IRTools.push!(block, return_record)
            
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
        p[variable] = IRTools.stmt(DCGCall.record!(tape, reified_call, statement.expr.args...),
                                   line = statement.line)
    elseif statement.expr isa QuoteNode
        # for statements that are just constants (like type literals)
        constant_expr = DCGCall.Constant(variable)
        constant_record = IRTools.stmt(DCGCall.record!(tape, constant_expr),
                                       line = statement.line)
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
    tape = IRTools.substitute(p, tape)

    # update all return values to include `tape`
    for block in IRTools.blocks(new_ir)
        update_returns!(block, tape)
    end

    return new_ir
end



export track

IRTools.@dynamo function track(F, args...)
    # println("handling $F with args $args")
    ir = IRTools.IR(F, args...)
    if isnothing(ir)
        @error "You probably tried tracking a builting function: $F"
    end
    
    new_ir = track_ir(ir)
    # @show ir
    # @show new_ir
    return new_ir
end

