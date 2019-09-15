mutable struct TrackBuilder
    original_ir::IRTools.IR
    new_ir::IRTools.IR
    variable_map::Dict{Any, Any}
    jump_targets::Dict{Int, Vector{Int}}
    return_block::Int
    tape::Union{IRTools.Variable, Nothing}

    TrackBuilder(o, n, v, j, r) = new(o, n, v, j, r)
end

function TrackBuilder(ir)
    new_ir = empty(ir)
    variable_map = Dict{Any, Any}()
    jump_targets = jumptargets(ir)
    return_block = length(ir.blocks) + 1

    TrackBuilder(ir, new_ir, variable_map, jump_targets, return_block)
end


substitute(builder::TrackBuilder, x) = get(builder.variable_map, x, x)
substitute(builder::TrackBuilder) = x -> substitute(builder, x)

record_substitution!(builder::TrackBuilder, x, y) = (push!(builder.variable_map, x => y); builder)

function jumptargets(ir::IRTools.IR)
    targets = Dict{Int, Vector{Int}}()
    pushtarget!(from, to) = push!(get!(targets, to, Int[]), from)
    
    for block in IRTools.blocks(ir)
        branches = IRTools.branches(block)
        
        for branch in branches
            if !IRTools.isreturn(branch)
                pushtarget!(block.id, branch.block)

                if IRTools.isconditional(branch) && branch == branches[end]
                    # conditional branch with fallthrough (last of all)
                    pushtarget!(block.id, block.id + 1)
                end
            end
        end
    end

    return targets
end




function track_branches!(block::IRTools.Block, builder::TrackBuilder, branches)
    pseudo_return!(block, args...) = IRTools.branch!(block, builder.return_block, args...)
    
    # called only from within a non-primitive call
    for (position, branch) in enumerate(branches)
        index = DCGCall.BranchIndex(block.id, position)
        args = map(substitute(builder), branch.args)
        reified_args = map(reify_quote, branch.args)
        
        if IRTools.isreturn(branch)
            @assert length(branch.args) == 1
            
            # record return statement
            return_record = push!(block, DCGCall.Return(reified_args[1], args[1], index))
            pseudo_return!(block, args[1], return_record)
        else
            condition = substitute(builder, branch.condition)
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


function track_statement!(block::IRTools.Block, builder::TrackBuilder, variable, statement)
    index = DCGCall.VarIndex(block.id, variable.id)
    expr = statement.expr
    reified_expr = reify_quote(statement.expr)
    
    if Meta.isexpr(expr, :call)
        args = map(substitute(builder), expr.args)
        stmt_record = IRTools.stmt(DCGCall.record!(builder.tape, index, reified_expr, args...),
                                   line = statement.line)
        r = push!(block, stmt_record)
        record_substitution!(builder, variable, r)
    elseif expr isa Expr
        # other special things, like `:new`, `:boundscheck`, or `:foreigncall`
        args = map(substitute(builder), expr.args)
        special_evaluation = Expr(expr.head, args...)
        special_value = push!(block, special_evaluation)
        special_expr = DCGCall.SpecialStatement(reified_expr, special_value, index)
        special_record = IRTools.stmt(DCGCall.record!(builder.tape, special_expr),
                                      line = statement.line)
        r = push!(block, special_record)
        record_substitution!(builder, variable, r)
    elseif expr isa QuoteNode || expr isa GlobalRef
        # for statements that are just constants (like type literals), or global values
        constant_expr = DCGCall.Constant(expr, index)
        # TODO: make constant_expr itself a constant :)
        constant_record = IRTools.stmt(DCGCall.record!(builder.tape, constant_expr),
                                       line = statement.line)
        r = push!(block, constant_record)
        record_substitution!(builder, variable, r)
    else
        # currently unhandled
        error("Found statement of unknown type: ", statement)
    end
    
    return nothing
end


function copy_argument!(block::IRTools.Block, builder::TrackBuilder, argument)
    # without `insert = false`, `nothing` gets added to branches pointing here
    new_argument = IRTools.argument!(block, insert = false)
    record_substitution!(builder, argument, new_argument)
end


function track_argument!(block::IRTools.Block, builder::TrackBuilder, argument)
    index = DCGCall.VarIndex(block.id, argument.id)
    new_argument = substitute(builder, argument)
    argument_record = DCGCall.record!(builder.tape, DCGCall.Argument(new_argument, index))
    push!(block, argument_record)
end


function track_jump!(new_block::IRTools.Block, builder::TrackBuilder, branch_argument)
    jump_record = DCGCall.record!(builder.tape, branch_argument)
    push!(new_block, jump_record)
end


function track_block!(new_block::IRTools.Block, builder::TrackBuilder, old_block; first = false)
    @assert first || !isnothing(builder.tape)

    # copy over arguments from old block
    for argument in IRTools.arguments(old_block)
        copy_argument!(new_block, builder, argument)
    end

    # if this is the first block, set up the tape
    first && (builder.tape = push!(new_block, DCGCall.GraphTape(copy(builder.original_ir))))

    # record branches to here, if there are any, by adding a new argument
    if haskey(builder.jump_targets, old_block.id)
        branch_argument = IRTools.argument!(new_block, insert = false)
        track_jump!(new_block, builder, branch_argument)
    end

    # record rest of the arguments from the old block
    for argument in IRTools.arguments(old_block)
        track_argument!(new_block, builder, argument)
    end

    # handle statement recording (nested vs. primitive is handled in `record!`)
    for (v, stmt) in old_block
        track_statement!(new_block, builder, v, stmt)
    end

    # set up branch tracking and returning the tape
    track_branches!(new_block, builder, IRTools.branches(old_block))

    return new_block
end


# tracking the first block is special, because only there the tape is set up
track_first_block!(new_block::IRTools.Block, builder::TrackBuilder, old_block) =
    track_block!(new_block, builder, old_block, first = true)


function setup_return_block!(builder::TrackBuilder)
    return_block = IRTools.block!(builder.new_ir)
    @assert return_block.id == builder.return_block
    
    return_value = IRTools.argument!(return_block, insert = false)
    push!(return_block, DCGCall.record!(builder.tape, IRTools.argument!(return_block, insert = false)))
    IRTools.return!(return_block, IRTools.xcall(:tuple, return_value, builder.tape))
    return return_block
end



function build_tracks!(builder::TrackBuilder)
    # in new_ir, the first block is already set up automatically, 
    # so we just use it and set up the tape there
    old_first_block = IRTools.block(builder.original_ir, 1)
    new_first_block = IRTools.block(builder.new_ir, 1)
    return_block = length(builder.original_ir.blocks) + 1

    track_first_block!(new_first_block, builder, old_first_block)

    # the rest of the blocks needs to be created newly, and can use `tape`.
    for (i, old_block) in enumerate(IRTools.blocks(builder.original_ir))
        i == 1 && continue
        
        new_block = IRTools.block!(builder.new_ir, i)
        track_block!(new_block, builder, old_block)
    end
    
    # now we set up a block at the last position, to which all return statements redirect.
    setup_return_block!(builder).id == return_block

    return builder.new_ir
end
