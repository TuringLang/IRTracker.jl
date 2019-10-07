using Test
using DynamicComputationGraphs
using IRTools: @code_ir


########### Basic sanity checks #################
# f(x) = x + 1
# track(f, 42)

weird(n) = rand() < 1/(n + 1) ? n : weird(n + 1)
track(weird, 3)

geom(n, β) = rand() < β ? n : geom(n + 1, β)
track(geom, 3, 0.5)

function test1(x)
    t = (x, x)
    t[1] + 1
end
track(test1, 42)

function test2(x)
    if x < 0
        return x + 1
    else
        return x - 1 #sum([x, x])
    end
end
track(test2, 42)

function test3(x)
    y = 0 #zero(x)
    while x > 0
        y += 1
        x -= 1
    end

    return y
end
track(test3, 42)

test4(x) = [x, x]
track(test4, 42)

# check visible result
result, graph = track(geom, 3, 0.6)
@show @code_ir geom(3, 0.6)
printlevels(graph, 2)
println("\n")

# @show @code_ir test2(0.3)
# println(@code_ir test2(3))
# track(geom, 2, 0.5)
# @show graph
# track(weird, 2)
# @show track(typeof, 1)



########### Graph API #################
# println(IOContext(stdout, :maxlevel => 1), parents(graph[end-1]))
