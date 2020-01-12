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

function trackednested(ctx::DepthLimitContext, f_repr::TapeExpr,
                       args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    new_ctx = increase_level(ctx)
    return recordnestedcall(new_ctx, f_repr, args_repr, info)
end
