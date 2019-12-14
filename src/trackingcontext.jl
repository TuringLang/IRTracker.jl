abstract type AbstractTrackingContext end

"""Tracks everything down to calls of intrinsic functions."""
struct DefaultTrackingContext <: AbstractTrackingContext end

const DEFAULT_CTX = DefaultTrackingContext()



"""Tracks nested calls until a certain level."""
struct DepthLimitContext <: AbstractTrackingContext
    level::Int
    maxlevel::Int
end

DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)

increase_level(ctx::DepthLimitContext) = DepthLimitContext(ctx.level + 1, ctx.maxlevel)

canrecur(ctx::DepthLimitContext, f, args...) = ctx.level < ctx.maxlevel

function tracknested(ctx::DepthLimitContext, f, f_repr, args, args_repr, info)
    new_ctx = increase_level(ctx)
    return recordnested(new_ctx, f, f_repr, args, args_repr, info)
end
