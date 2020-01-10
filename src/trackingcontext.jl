abstract type AbstractTrackingContext end

"""Tracks everything down to calls of intrinsic functions."""
struct DefaultTrackingContext <: AbstractTrackingContext end

const DEFAULT_CTX = DefaultTrackingContext()



"""Tracks nested calls until a certain level."""
mutable struct DepthLimitContext <: AbstractTrackingContext
    level::Int
    maxlevel::Int
end

DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)

canrecur(ctx::DepthLimitContext, f, args...) = ctx.level < ctx.maxlevel

function tracknested(ctx::DepthLimitContext, node::NestedCallNode)
    ctx.level += 1
    return node
end
