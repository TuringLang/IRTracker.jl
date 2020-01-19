using ChainRules
import DynamicComputationGraphs: trackedcall


# @testset "contexts" begin
    # f(x) = sin(x) + 1
    # julia> printlevels(track(f, 42), 3)
    # f(42) = 0.08347845208436622
    #   @1: [Argument §1:%1] = f
    #   @2: [Argument §1:%2] = 42
    #   @3: [§1:%3] sin(@2) = -0.9165215479156338
    #     @1: [Argument §1:%1] = sin
    #     @2: [Argument §1:%2] = 42
    #     @3: [§1:%3] float(@2) = 42.0
    #     @4: [§1:%4] sin(@3) = -0.9165215479156338
    #     @5: [§1:1] return @4 = -0.9165215479156338
    #   @4: [§1:%4] +(@3, 1) = 0.08347845208436622
    #     @1: [Argument §1:%1] = +
    #     @2: [Argument §1:%2] = -0.9165215479156338
    #     @3: [Argument §1:%3] = 1
    #     @4: [§1:%4] promote(@2, @3) = (-0.9165215479156338, 1.0)
    #     @5: [§1:%5] Core._apply(+, @4) = 0.08347845208436622
    #     @6: [§1:1] return @5 = 0.08347845208436622
    #   @5: [§1:1] return @4 = 0.08347845208436622


    # # Limit recording to a maximum layer -- see implementation in src/trackingcontext.jl
    # let ctx = DepthLimitContext(2), call = track(ctx, f, 42)
    #     @test length(getchildren(call)) == 5
    #     @test call[3] isa PrimitiveCallNode
    #     @test call[4] isa PrimitiveCallNode
    #     getmetadata(call)[:bla] = 1
    #     getmetadata(call)[:blub] = nothing
    #     getmetadata(call[3])[:value] = "sdfd"
    #     getmetadata(call[4])[:∂] = 1.234234
    # end

    # let ctx = DepthLimitContext(2), call = track(ctx, union!, [1], [2])
    #     @test all(!(c isa NestedCallNode) for c in getchildren(call))
    # end

    
    # Backward differentiation
    struct BDiffContext <: AbstractTrackingContext end

    function refs(node::Union{NestedCallNode, PrimitiveCallNode})
        f_ref = node.call.f isa TapeReference ?
            Pair{Int, AbstractNode}[1 => node.call.f[]] :
            Pair{Int, AbstractNode}[]
        arg_refs = (i+1 => e[] for (i, e) in enumerate(node.call.arguments) if e isa TapeReference)
        return append!(f_ref, arg_refs)
    end

    function refs(node::SpecialCallNode)
        arg_refs = (i+1 => e[] for (i, e) in enumerate(node.form.arguments) if e isa TapeReference)
        return append!(f_ref, arg_refs)
    end

    function refs(node::ReturnNode)
        return node.argument isa TapeReference ?
            Pair{Int, AbstractNode}[1 => node.argument[]] :
            Pair{Int, AbstractNode}[]
    end

    function refs(node::JumpNode)
        cond_ref = node.condition isa TapeReference ?
            Pair{Int, AbstractNode}[1 => node.condition[]] :
            Pair{Int, AbstractNode}[]
        arg_refs = (i+1 => e[] for (i, e) in enumerate(node.arguments) if e isa TapeReference)
        return append!(cond_ref, arg_refs)
    end

    refs(::AbstractNode) = Pair{Int, AbstractNode}[]

    accumulate!(node, x̄) = setmetadata!(node, :Ω̄, getmetadata(node, :Ω̄, Zero()) .+ x̄)

    function pullback!(node::PrimitiveCallNode, Ω̄)
        x̄ = getmetadata(node, :pullback)(Ω̄)
        for (i, ref) in refs(node)
            accumulate!(ref, x̄[i])
        end

        return node
    end

    function pullback!(node::AbstractNode, Ω̄)
        for (i, ref) in refs(node)
            accumulate!(ref, Ω̄)
        end

        return node
    end

    function pullback!(node::NestedCallNode, Ω̄)
        setmetadata!(node[end], :Ω̄, Ω̄)
        pullback!(node[end], Ω̄)
        
        for child in backward(node[end])
            Ω̄ = getmetadata!(child, :Ω̄, Zero())
            pullback!(child, Ω̄)
        end

        args = getarguments(node)
        for (i, ref) in refs(node)
            accumulate!(ref, getmetadata(args[i], :Ω̄, Zero()))
        end

        return node
    end
    
    function trackedcall(ctx::BDiffContext, f_repr::TapeExpr,
                         args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
        f, args = getvalue(f_repr), getvalue.(args_repr)
        rule = rrule(f, args...)
        
        if !isnothing(rule)                # `f` is primitively differentiable wrt. `args`
            result, pullback = rule        # we can reuse the result from the rrule!
            primitive_call = trackedprimitive(ctx, result, f_repr, args_repr, info)
            setmetadata!(primitive_call, :pullback, pullback)
            return primitive_call
        elseif isbuiltin(f)
            return trackedprimitive(ctx, f(args...), f_repr, args_repr, info)
        else
            nested_call = recordnestedcall(ctx, f_repr, args_repr, info)
            return nested_call
        end
    end

    function grad(f, args...)
        call = track(BDiffContext(), f, args...)
        pullback!(call, 1)
        return [getmetadata(arg, :Ω̄, Zero()) for arg in getarguments(call)]
    end
    
    # let ctx = BDiffContext(), call = track(ctx, f, 42)
    #     ∇f = metadata(call)[:adjoint]
    #     @test length(call) == 5
    #     @test call[3] isa PrimitiveCallNode
    #     @test call[4] isa PrimitiveCallNode
    # end
# end
