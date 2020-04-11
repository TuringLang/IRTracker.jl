"""
    AbstractTrackingContext

Abstract base type for tracking contexts, on which the tracking functionality can be dispatched on.
"""
abstract type AbstractTrackingContext end

"""
    DefaultTrackingContext

Context for everything all function calls, down to Julia intrinsic functions (see
[`isbuiltin`](@ref)).
"""
struct DefaultTrackingContext <: AbstractTrackingContext end

const DEFAULT_CTX = DefaultTrackingContext()



"""
    DepthLimitContext(maxlevel)

Context to track all function calls down to `maxlevel` nesting levels (or until they are builtins).
"""
struct DepthLimitContext <: AbstractTrackingContext
    level::Int
    maxlevel::Int
end

DepthLimitContext(maxlevel) = DepthLimitContext(1, maxlevel)


increase_level(ctx::DepthLimitContext) = DepthLimitContext(ctx.level + 1, ctx.maxlevel)

canrecur(ctx::DepthLimitContext, f, args...) = ctx.level < ctx.maxlevel

function trackednested(ctx::DepthLimitContext, f_repr::TapeValue,
                       args_repr::ArgumentTuple{TapeValue}, info::NodeInfo)
    new_ctx = increase_level(ctx)
    return recordnestedcall(new_ctx, f_repr, args_repr, info)
end



"""
    ComposedContext(contexts...)

DRAFT. Composes behaviour of a series of other contexts (right to left, as with functions).
"""
struct ComposedContext{T<:Tuple{Vararg{AbstractTrackingContext}}} <: AbstractTrackingContext
    contexts::T
    ComposedContext(contexts::T) where {T<:Tuple{Vararg{AbstractTrackingContext}}} =
        new{T}(contexts)
end

ComposedContext(ctx::AbstractTrackingContext, contexts::AbstractTrackingContext...) =
    ComposedContext((ctx, contexts...))


function foldcontexts(composed::ComposedContext, track, args...)
    contexts = composed.contexts
    C = length(contexts)
    node = track(contexts[end], args...)
    
    for c = C:-1:2
        node = track(composed.context[c], args...)
    end

    return node
end


trackedreturn(composed::ComposedContext, arg_repr::TapeValue, info::NodeInfo) =
    foldcontexts(composed, arg_repr, info)

trackedjump(composed::ComposedContext, target::Int, args_repr::ArgumentTuple{TapeValue},
            cond_repr::TapeValue, info::NodeInfo) =
                foldcontexts(composed, target, args_repr, cond_repr, info)

trackedspecial(composed::ComposedContext, form_repr::TapeSpecialForm, info::NodeInfo) =
    foldcontexts(composed, form_repr, info)

trackedconstant(composed::ComposedContext, const_repr::TapeValue, info::NodeInfo) =
    foldcontexts(composed, const_repr, info)

trackedargument(composed::ComposedContext, arg_repr::TapeValue, number::Int, info::NodeInfo) =
    foldcontexts(composed, arg_repr, number, info)

trackedprimitive(composed::ComposedContext, f_repr::TapeValue,
                 args_repr::ArgumentTuple{TapeValue}, info::NodeInfo) =
                     foldcontexts(composed, f_repr, args_repr, info)

trackednested(composed::ComposedContext, f_repr::TapeValue,
              args_repr::ArgumentTuple{TapeValue}, info::NodeInfo) =
                  foldcontexts(composed, f_repr, args_repr, info)

canrecur(composed::ComposedContext, f, args...) =
    any(canrecur(ctx, f, args...) for ctx in composed.contexts)
