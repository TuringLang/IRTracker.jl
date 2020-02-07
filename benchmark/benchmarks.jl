using BenchmarkTools
using Random: MersenneTwister

using IRTracker

const SUITE = BenchmarkGroup()
const RNG = MersenneTwister(42)

f1(x) = x + 1
f2(n) = rand(RNG) < 1/(n + 1) ? n : f2(n + 1)

SUITE["basics"] = BenchmarkGroup()
SUITE["basics"]["f1"] = @benchmarkable track($f1, 1)
SUITE["basics"]["f1_baseline"] = @benchmarkable f1(1)

# SUITE["basics"]["f2"] = @benchmarkable f2($(1))

