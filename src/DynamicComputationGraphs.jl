module DynamicComputationGraphs

include("graph.jl")
include("tape.jl")
include("tracker.jl")



f(x) = x + 1
println(track(f, 1))

end # module
