
"""
If `f` is primitive, call `f(args...)` and return a `PrimitiveCall` node with the result; otherwise,
track the call of `f` with `args` and return a `NestedCall` containing the resulting `GraphTape`.
"""
@generated function dispatchcall(f::F, f_repr, args, args_repr, location) where F
    # TODO: check this out:
    # @nospecialize args
    
    # from Cassette.canrecurse
    # (https://github.com/jrevels/Cassette.jl/blob/79eabe829a16b6612e0eba491d9f43dc9c11ff02/src/context.jl#L457-L473)
    mod = Base.typename(F).module
    is_builtin = ((F <: Core.Builtin) && !(mod === Core.Compiler)) || F <: Core.IntrinsicFunction

    tapecall = :(TapeCall(result, f_repr, args_repr))

    if is_builtin 
        quote
            result = f(args...)
            return PrimitiveCall($tapecall, location)
        end
    else
        quote
            result, graph = track(f, args...)
            return NestedCall($tapecall, graph, location)
        end
    end
end


"""
Special handling to get the name of the intrinsic function `f` and print an error message that it 
can't be tracked.
"""
function print_intrinsic_error(f::Core.IntrinsicFunction, args...)
    # from https://github.com/JuliaLang/julia/blob/c6da87ff4bc7a855e217856757ad3413cf6d1f79/base/show.jl#L398
    name = unsafe_string(ccall(:jl_intrinsic_name, Cstring, (Core.IntrinsicFunction,), f))
    error("Can't track the intrinsic function ", name, " with arguments ",
          join(args, ", "))
end
