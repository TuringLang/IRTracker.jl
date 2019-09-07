using IRTools


record!(tape::GraphTape, node::Node) = (push!(tape, node); value(node))

@generated function record!(tape::GraphTape, index::StmtIndex, expr, f::F, args...) where F
    # TODO: check this out:
    # @nospecialize args
    
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
        args = map(substitute(vm), branch.args)
        reified_args = map(reify_quote, branch.args)
        
        if IRTools.isreturn(branch)
            @assert length(branch.args) == 1
            
            # record return statement
            return_record = DCGCall.record!(tape, DCGCall.Return(reified_args[1],
                                                                 args[1],
                                                                 index))
            push!(block, return_record)

            # modify return branch to include tape
            return_expr = IRTools.xcall(:tuple, args..., tape)
            return_value = push!(block, return_expr)
            IRTools.return!(block, return_value)
        else
            condition = substitute(vm, branch.condition)
            reified_condition = reify_quote(branch.condition)
            
            # remember from where and why we branched in target_info
            arg_exprs = IRTools.xcall(:vect, reified_args...)
            arg_values = IRTools.xcall(:vect, args...)
            jump_record = DCGCall.Branch(branch.block, arg_exprs, arg_values,
                                         reified_condition, index)
            target_info = push!(block, jump_record)

            # extend branch args by target_info
            IRTools.branch!(block, branch.block, args..., target_info; unless = condition)
        end
    end

    return block
end


function track_statement!(block::IRTools.Block, vm::VariableMap, tape, variable, statement)
    index = DCGCall.StmtIndex(variable.id)
    expr = statement.expr
    reified_expr = reify_quote(statement.expr)
    
    if Meta.isexpr(expr, :call)
        args = map(substitute(vm), expr.args)
        stmt_record = IRTools.stmt(DCGCall.record!(tape, index, reified_expr, args...),
                                   line = statement.line)
        r = push!(block, stmt_record)
        record_substitution!(vm, variable, r)
    elseif expr isa Expr
        # other special things, like `:boundscheck` or `:foreigncall`
        special_expr = DCGCall.SpecialStatement(reified_expr, variable, index)
        special_record = IRTools.stmt(DCGCall.record!(tape, special_expr),
                                      line = statement.line)
        r = push!(block, special_record)
        record_substitution!(vm, variable, r)
    elseif expr isa QuoteNode
        # for statements that are just constants (like type literals)
        constant_expr = DCGCall.Constant(expr, index)
        constant_record = IRTools.stmt(DCGCall.record!(tape, constant_expr),
                                       line = statement.line)
        r = push!(block, constant_record)
        record_substitution!(vm, variable, r)
    else
        # currently unhandled and simply kept
        @warn "Unknown statement type type $statement found!"
    end
    
    return nothing
end


function copy_argument!(block::IRTools.Block, vm::VariableMap, argument)
    # without `insert = false`, `nothing` gets added to branches pointing here
    new_argument = IRTools.argument!(block, insert = false)
    record_substitution!(vm, argument, new_argument)
end


function track_argument!(block::IRTools.Block, vm::VariableMap, tape, argument)
    index = DCGCall.StmtIndex(argument.id)
    new_argument = substitute(vm, argument)
    argument_record = DCGCall.record!(tape, DCGCall.Argument(new_argument, index))
    push!(block, argument_record)
end


function track_jump!(new_block::IRTools.Block, tape, branch_argument)
    jump_record = DCGCall.record!(tape, branch_argument)
    push!(new_block, jump_record)
end


function track_block!(new_block::IRTools.Block, vm::VariableMap, jt::JumpTargets, tape, old_block;
                      first = false)
    @assert first || !isnothing(tape)

    # copy over arguments from old block
    for argument in IRTools.arguments(old_block)
        copy_argument!(new_block, vm, argument)
    end

    # if this is the first block, set up the tape
    first && (tape = push!(new_block, DCGCall.GraphTape()))

    # record branches to here, if there are any, by adding a new argument
    if haskey(jt, old_block.id)
        branch_argument = IRTools.argument!(new_block, insert = false)
        track_jump!(new_block, tape, branch_argument)
    end

    # record rest of the arguments from the old block
    for argument in IRTools.arguments(old_block)
        track_argument!(new_block, vm, tape, argument)
    end

    # handle statement recording (nested vs. primitive is handled in `record!`)
    for (v, stmt) in old_block
        track_statement!(new_block, vm, tape, v, stmt)
    end

    # set up branch tracking and returning the tape
    track_branches!(new_block, vm, IRTools.branches(old_block), tape)

    return tape
end


# tracking the first block is special, because only there the tape is set up
track_first_block!(new_block::IRTools.Block, vm::VariableMap, jt::JumpTargets, old_block) =
    track_block!(new_block, vm, jt, nothing, old_block, first = true)


function track_ir(old_ir::IRTools.IR)
    IRTools.explicitbranch!(old_ir) # make implicit jumps explicit
    new_ir = IRTools.empty(old_ir)
    vm = VariableMap()
    jt = jumptargets(old_ir)

    # in new_ir, the first block is already set up automatically, 
    # so we just use it and set up the tape there
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
    # create empty IR which matches the (non-existing) signature given by f(args)
    dummy(args...) = nothing
    ir = IRTools.empty(IRTools.IR(IRTools.meta(Tuple{Core.Typeof(dummy), Core.Typeof.(args)...})))
    
    self = IRTools.argument!(ir)
    arg_values = ntuple(_ -> IRTools.argument!(ir), length(args))

    if F <: Core.IntrinsicFunction
        error_result = push!(ir, DCGCall.print_intrinsic_error(self, arg_values...))
        IRTools.return!(ir, error_result)
        return ir
    else
        error_result = push!(ir, IRTools.xcall(:error, "Can't track ", F,
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
        @show ir
        @show new_ir
        return new_ir
    end
    
end

