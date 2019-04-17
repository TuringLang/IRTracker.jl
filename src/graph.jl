# struct Call{F, As<:Tuple}
#     func::F
#     args::As
# end

# Call(f::F, args::T) where {F, T} = Call{F, T}(f, args)
# Call() = Call(nothing, ())

# # When deserialising, the object_id changes
# Base.:(==)(a::Call, b::Call) = a.func == b.func && a.args == b.args

# @inline (c::Call)() = c.func(data.(c.args)...)

import Base: show

struct Call{F, As<:Tuple}
    func::F
    args::As
    body::Vector{Call}
end

Call(f::F, args::As) where {F, As<:Tuple} = Call{F, As}(f, args, Call[])

function show(io::IO, call::Call, indent = 0)
    print(io, " " ^ indent)
    print(io, "(")
    join(io, (call.func, call.args...), " ")
    print(io, ")\n")
    
    for c in call.body
        show(io, c, indent + 2)
    end
end
