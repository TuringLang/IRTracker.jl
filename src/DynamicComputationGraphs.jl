module DynamicComputationGraphs

include("utils.jl")
include("graph.jl")
include("show.jl")
# include("tape.jl")
include("tracker.jl")



f(x) = x + 1

weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)

function test(x)
    t = (x, x)
    t[1] + 1
end

result, graph = track(test, 1)
@show graph
@show @code_ir test(1)
# track(weird, 2)
# @show track(typeof, 1)

end # module
