module DynamicComputationGraphs

include("utils.jl")
include("graph.jl")
include("show.jl")
include("irbuilder.jl")
include("tracker.jl")



f(x) = x + 1

weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)
geom(n, β) = rand() < β ? n : geom(n + 1, β)

function test1(x)
    t = (x, x)
    t[1] + 1
end

function test2(x)
    if x < 0
        return x + 1
    else
        return x - 1 #sum([x, x])
    end
end

function test3(x)
    y = 0 #zero(x)
    while x > 0
        y += 1
        x -= 1
    end

    return y
end

test4(x) = [x, x]

# @show @code_ir test2(0.3)
result, graph = track(weird, 3)
printlevels(graph, 2)
# track(geom, 2, 0.5)
# @show graph
# track(weird, 2)
# @show track(typeof, 1)



end # module
