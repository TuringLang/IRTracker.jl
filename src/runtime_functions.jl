
function isbuiltin(f::F, args...) where {F}
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    mod = Base.typename(F).module
    return ((F <: Core.Builtin) && !(mod === Core.Compiler))
end

isbuiltin(f::Core.IntrinsicFunction, args...) = true



"""
Print an error message that `f(args...)` can't be tracked (because the method does not exist, or `f`
is intrinsic.)
"""
function trackingerror(f::F, args...) where F
    error("No method for call ", f, "(", join(args, ", "), ")")
end

function trackingerror(f::Core.IntrinsicFunction, args...)
    # Special handling is needed to get the name of an intrinsic function; see
    # https://github.com/JuliaLang/julia/blob/c6da87ff4bc7a855e217856757ad3413cf6d1f79/base/show.jl#L398
    name = unsafe_string(ccall(:jl_intrinsic_name, Cstring, (Core.IntrinsicFunction,), f))
    error("Can't track intrinsic function ", name, " with arguments ",
          join(args, ", "))
end

