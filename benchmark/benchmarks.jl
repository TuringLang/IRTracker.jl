using BenchmarkTools
using Random: MersenneTwister

using IRTracker

const SUITE = BenchmarkGroup()
const RNG = MersenneTwister(42)

f1(x) = x + 1
f2(n) = rand(RNG) < 1/(n + 1) ? n : f2(n + 1)

SUITE["tracking"] = BenchmarkGroup()
SUITE["tracking"]["f1"] = @benchmarkable track($f1, 1)

SUITE["baseline"] = BenchmarkGroup()
SUITE["baseline"]["f1"] = @benchmarkable f1(1)
SUITE["baseline"]["f2"] = @benchmarkable f2(1)

