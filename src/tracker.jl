using IRTools


record!(tape::GraphTape, value::Node) =
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
        index = DCGCall.BranchIndex(block.id, position)
        arguments = [substitute(vm, arg) for arg in branch.args]
        reified_arguments = map(reify_quote, branch.args)
        
        if IRTools.isreturn(branch)
            @assert length(arguments) == 1
            return_record = DCGCall.record!(tape, DCGCall.Return(reified_arguments[1],
                                                                 arguments[1],
                                                                 index))
            push!(block, return_record)
            
            return_expr = IRTools.xcall(:tuple, arguments..., tape)
            return_value = push!(block, return_expr)
            IRTools.return!(block, return_value)

        else
            # TODO record better information here
            arg_exprs = IRTools.xcall(:vect, reified_arguments...)
            arg_values = IRTools.xcall(:vect, arguments...)
            condition_expr = reify_quote(branch.condition)
            jump_record = DCGCall.Branch(branch.block, arg_exprs, arg_values, condition_expr, index)
            condition = substitute(vm, branch.condition)
            target_info = push!(block, jump_record)
            IRTools.branch!(block, branch.block, arguments..., target_info; unless = condition)
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
        # other special things, like `:boundscheck` or `:foreigncall`
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


function copy_argument!(block::IRTools.Block, vm::VariableMap, argument)
    # without `insert = false`, `nothing` gets added to branches pointing here
    new_argument = IRTools.argument!(block, insert = false)
    record_substitution!(vm, argument, new_argument)
end


function track_argument!(block::IRTools.Block, vm::VariableMap, tape, argument)
    index = push!(block, DCGCall.StmtIndex(argument.id))
    new_argument = substitute(vm, argument)
    argument_record = DCGCall.record!(tape, DCGCall.Argument(new_argument, index))
    push!(block, argument_record)
end


function track_first_block!(new_block::IRTools.Block, vm::VariableMap, jt::JumpTargets, old_block)
    # we should insert new argument slots for block before adding the tape
    for argument in IRTools.arguments(old_block)
        copy_argument!(new_block, vm, argument)
    end

    tape = push!(new_block, DCGCall.GraphTape())
    
    for argument in IRTools.arguments(old_block)
        track_argument!(new_block, vm, tape, argument)
    end
    
    for (v, stmt) in old_block
        track_statement!(new_block, vm, tape, v, stmt)
    end
    
    track_branches!(new_block, vm, IRTools.branches(old_block), tape)

    return tape
end


function track_jump!(new_block::IRTools.Block, tape, branch_argument)
    jump_record = DCGCall.record!(tape, branch_argument)
    push!(new_block, jump_record)
end


function track_block!(new_block::IRTools.Block, vm::VariableMap, jt::JumpTargets, tape, old_block)
    for argument in IRTools.arguments(old_block)
        copy_argument!(new_block, vm, argument)
        track_argument!(new_block, vm, tape, argument)
    end

    # record phi node here
    if haskey(jt, old_block.id)
        branch_argument = IRTools.argument!(new_block, insert = false)
        track_jump!(new_block, tape, branch_argument)
    end
    
    for (v, stmt) in old_block
        track_statement!(new_block, vm, tape, v, stmt)
    end
    
    track_branches!(new_block, vm, IRTools.branches(old_block), tape)
end


function track_ir(old_ir::IRTools.IR)
    new_ir = IRTools.empty(old_ir)
    vm = VariableMap()
    jt = jumptargets(old_ir)

    old_first_block = IRTools.block(old_ir, 1)
    new_first_block = IRTools.block(new_ir, 1)
    tape = track_first_block!(new_first_block, vm, jt, old_first_block)
    
    for old_block in Iterators.drop(IRTools.blocks(old_ir), 1)
        new_block = IRTools.block!(new_ir)
        track_block!(new_block, vm, jt, tape, old_block)
    end

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
                                               " with args ", join(args, ", ")))
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
        @show new_ir
        return new_ir
    end
    
end

