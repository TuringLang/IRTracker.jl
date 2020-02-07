using Pkg
using PkgBenchmark

import IRTracker


results = benchmarkpkg("IRTracker")

pkgid = Base.identify_package("IRTracker")
pkgfile = Base.locate_package(pkgid)
pkgdir = normpath(joinpath(dirname(pkgfile), ".."))
resultspath = joinpath(pkgdir, "benchmark", "results.md")
export_markdown(resultspath, results)
println("Wrote results markdown to: $resultspath")
