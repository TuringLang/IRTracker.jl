abstract type AbstractTrackingContext end

struct DefaultTrackingContext <: AbstractTrackingContext end


# FALLBACK IMPLEMENTATIONS
function isprimitive(::AbstractTrackingContext, ::F) where {F}
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    mod = Base.typename(F).module
    return ((F <: Core.Builtin) && !(mod === Core.Compiler)) || F <: Core.IntrinsicFunction
end
