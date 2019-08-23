module DynamicComputationGraphs

include("utils.jl")
include("graph.jl")
include("show.jl")
include("tracker.jl")



f(x) = x + 1

weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)

function test1(x)
    t = (x, x)
    t[1] + 1
end

function test2(x)
    if x < 0.5
        return x + 1
    else
        return sum([x, x])
    end
end

# @show @code_ir test2(0.3)
result, graph = track(test1, 0.3)
@show graph
# track(weird, 2)
# @show track(typeof, 1)

end # module
