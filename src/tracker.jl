using IRTools


record!(tape::GraphTape, value::Union{Argument, Constant, Return, SpecialStatement}) =
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


function track_branches!(block::IRTools.Block, vm::VariableMap, branches, tape)
    # called only from within a non-primitive call
    for (position, branch) in enumerate(branches)
        if IRTools.isreturn(branch)
            return_arg = substitute(vm, branch.args[1])
            reified_return_arg = reify_quote(branch.args[1])
            
            index = DCGCall.BranchIndex(block.id, position)
            return_record = DCGCall.record!(tape, DCGCall.Return(reified_return_arg,
                                                                 return_arg,
                                                                 index))
            push!(block, return_record)
            
            return_expr = IRTools.xcall(:tuple, return_arg, tape)
            return_value = push!(block, return_expr)
            IRTools.return!(block, return_value)
        end
    end

    return block
end


function track_statement!(block::IRTools.Block, vm::VariableMap, tape, variable, statement)
    if Meta.isexpr(statement.expr, :call)
        index = push!(block, DCGCall.StmtIndex(variable.id))
        reified_call = reify_quote(statement.expr)
        args = [substitute(vm, arg) for arg in statement.expr.args]
        stmt_record = IRTools.stmt(DCGCall.record!(tape, index, reified_call, args...),
                                   line = statement.line)
        r = push!(block, stmt_record)
        record_substitution!(vm, variable, r)
    elseif statement.expr isa Expr
        # other special things, like `:boundscheck` or `foreigncall`
        # TODO: handle some things specially? esp. foreigncall?
        index = push!(block, DCGCall.StmtIndex(variable.id))
        reified_call = reify_quote(statement.expr)
        special_expr = DCGCall.SpecialStatement(reified_call, variable, index)
        special_record = DCGCall.record!(tape, special_expr)
        r = push!(block, special_record)
        record_substitution!(vm, variable, r)
    elseif statement.expr isa QuoteNode
        # for statements that are just constants (like type literals)
        index = push!(block, DCGCall.StmtIndex(variable.id))
        constant_expr = DCGCall.Constant(variable, index)
        constant_record = IRTools.stmt(DCGCall.record!(tape, constant_expr),
                                       line = statement.line)
        r = push!(block, constant_record)
        record_substitution!(vm, variable, r)
    else
        # currently unhandled and simply kept
        # TODO: issue a warning here?
    end
    
    return nothing
end


function add_arguments!(block::IRTools.Block, vm::VariableMap, old_arguments)
    map(old_arguments) do old_argument
        argument = IRTools.argument!(block)
        record_substitution!(vm, old_argument, argument)
        argument
    end
end

function track_arguments!(block::IRTools.Block, vm::VariableMap, tape, arguments)
    for argument in arguments
        index = push!(block, DCGCall.StmtIndex(argument.id))
        argument_record = DCGCall.record!(tape, DCGCall.Argument(argument, index))
        push!(block, argument_record)
    end

    return nothing
end


function track_ir(old_ir::IRTools.IR)
    new_ir = IRTools.empty(old_ir)
    vm = VariableMap()
    tape = nothing

    for (b, old_block) in enumerate(IRTools.blocks(old_ir))
        if b != 1
            new_block = IRTools.block!(new_ir)
        else
            new_block = IRTools.block(new_ir, 1)
            arguments = add_arguments!(new_block, vm, IRTools.arguments(old_block))
            tape = push!(new_block, DCGCall.GraphTape())
            track_arguments!(new_block, vm, tape, arguments)
        end
        
        for (v, stmt) in old_block
            track_statement!(new_block, vm, tape, v, stmt)
        end
        
        track_branches!(new_block, vm, IRTools.branches(old_block), tape)
    end

    @show new_ir
    return new_ir
end


function error_ir(F, args...)
    dummy(args...) = nothing
    ir = IRTools.empty(IRTools.IR(IRTools.meta(Tuple{Core.Typeof(dummy), Core.Typeof.(args)...})))
    
    self = IRTools.argument!(ir)
    arg_values = ntuple(_ -> IRTools.argument!(ir), length(args))


    if F <: Core.IntrinsicFunction
        error_expr = DCGCall.print_intrinsic_error(self, arg_values...)
        error_result = push!(ir, error_expr)
        IRTools.return!(ir, error_result)
        return ir
    else
        error_result = push!(ir, IRTools.xcall(:error, "cannot handle ", F,
                                               " with args ", args...))
        IRTools.return!(ir, error_result)
        return ir
    end
end


export track


IRTools.@dynamo function track(F, args...)
    # println("handling $F with args $args")
    ir = IRTools.IR(F, args...)

    if isnothing(ir)
        return error_ir(F, args...)
    else
        new_ir = track_ir(ir)
        # @show ir
        # @show new_ir
        return new_ir
    end
    
end

