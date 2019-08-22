using IRTools


record!(tape::GraphTape, value::Union{Constant, Argument, Return}) =
    push!(tape, value)

@generated function record!(tape::GraphTape, index::StmtIndex, expr, f::F, args...) where F
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    mod = Base.typename(F).module
    is_builtin = ((F <: Core.Builtin) && !(mod === Core.Compiler)) || F <: Core.IntrinsicFunction

    if is_builtin 
        quote
            result = f(args...)
            call = PrimitiveCall(expr, result, index)
            push!(tape, call)
            return result
        end
    else
        quote
            result, graph = track(f, args...)
            call = NestedCall(expr, result, index, graph)
            push!(tape, call)
            return result
        end
    end
end


function update_returns!(block::IRTools.Block, tape)
    # called only from within a non-primitive call
    for (position, branch) in enumerate(IRTools.branches(block))
        if IRTools.isreturn(branch)
            return_arg = branch.args[1]
            reified_return_arg = string(return_arg)

            index = DCGCall.BranchIndex(block.id, position)
            return_record = DCGCall.record!(tape, DCGCall.Return(reified_return_arg, return_arg,
                                                                 index))
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
        index = IRTools.insert!(p, variable, DCGCall.StmtIndex(variable.id))
        reified_call = string(statement.expr)
        p[variable] = IRTools.stmt(DCGCall.record!(tape, index, reified_call, statement.expr.args...),
                                   line = statement.line)
    elseif statement.expr isa QuoteNode
        # for statements that are just constants (like type literals)
        index = IRTools.insert!(p, variable, DCGCall.StmtIndex(variable.id))
        constant_expr = DCGCall.Constant(variable, index)
        constant_record = IRTools.stmt(DCGCall.record!(tape, constant_expr),
                                       line = statement.line)
        IRTools.push!(p, constant_record)
    elseif Meta.isexpr(statement.expr, :foreigncall)
        # TODO: handle this specially?
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


function print_intrinsic_error(f::Core.IntrinsicFunction, args...)
    name = unsafe_string(ccall(:jl_intrinsic_name, Cstring, (Core.IntrinsicFunction,), f))
    error("Can't track the intrinsic function ", name, " with arguments ",
          join(args, ", "))
end


function error_ir(F, args...)
    dummy(args...) = nothing
    ir = IRTools.empty(IRTools.IR(IRTools.meta(Tuple{Core.Typeof(dummy), Core.Typeof.(args)...})))
    
    self = IRTools.argument!(ir)
    arg_values = ntuple(_ -> IRTools.argument!(ir), length(args))

    error_expr = DCGCall.print_intrinsic_error(self, arg_values...)
    error_result = push!(ir, error_expr)
    IRTools.return!(ir, error_result)
    return ir
end


export track


IRTools.@dynamo function track(F, args...)
    # println("handling $F with args $args")
    ir = IRTools.IR(F, args...)

    if isnothing(ir)
        return error_ir(F, args...)
    else
        new_ir = track_ir(ir)
        @show ir
        # @show new_ir 
        return new_ir
    end
    
end

