module DynamicComputationGraphs

include("graph.jl")
include("tape.jl")
include("tracker.jl")



f(x) = x + 1
weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)
@show r, graph = track(weird, 2)

end # module
