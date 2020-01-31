using ChainRules: rrule, One, Zero
using Zygote: gradient
import IRTracker: trackedcall


struct BDiffContext <: AbstractTrackingContext end

accumulate!(node, x̄) = setmetadata!(node, :Ω̄, getmetadata(node, :Ω̄, Zero()) .+ x̄)

function pullback!(node::PrimitiveCallNode, Ω̄)
    pullback = getmetadata(node, :pullback) do
        error("No pullback found for primitive: ", node.call.f)
    end

    x̄ = pullback(Ω̄)
    
    for (i, ref) in referenced(node; numbered = true)
        accumulate!(ref, x̄[i])
    end

    return node
end

function pullback!(node::AbstractNode, Ω̄)
    for (i, ref) in referenced(node; numbered = true)
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
    for (i, ref) in referenced(node; numbered = true)
        accumulate!(ref, getmetadata(args[i], :Ω̄, Zero()))
    end

    return node
end

function trackedcall(ctx::BDiffContext, f_repr::TapeExpr,
                     args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    local f, args = getvalue(f_repr), getvalue.(args_repr)
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
    node = track(BDiffContext(), f, args...)
    pullback!(node, One())
    args = getarguments(node)
    
    # leave out differential of function #self argument
    return ntuple(i -> getmetadata(args[i + 1], :Ω̄, nothing), length(args) - 1)
end



####################################################################################
# ACTUAL TEST

# simple function
f(x) = sin(x) + one(x)

# two arguments and nesting of primitives
g(x, y) = sin(x + cos(y)) + x * y

# control flow, non-differentiable second argument
function h(x, n)
    r = zero(x)
    i = 0
    while i < n
        r += x^i
        i += 1
    end
    return r
end

# combination of all custom functions above
# beware: inside a `@testset`, this becomes a closure and contains `getfield`!
ϕ(x) = h(f(g(2x, x/2)), 4)


@testset "backward mode AD" begin
    let call = track(BDiffContext(), f, 42.0)
        @test length(getchildren(call)) == 6
        @test call[3] isa PrimitiveCallNode
        @test call[4] isa PrimitiveCallNode
        @test call[5] isa PrimitiveCallNode
    end
    
    @test grad(f, 42.0) == gradient(f, 42.0)
    @test grad(g, 2.0, 3.0) == gradient(g, 2.0, 3.0)
    @test grad(h, 2.4, 4) == gradient(h, 2.4, 4)
    @test grad(h, 11.11, 1) == gradient(h, 11.11, 1)
    @test grad(ϕ, 1.1) == gradient(ϕ, 1.1)
end
