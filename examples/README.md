# Integration checks

These scripts run BrowserPlots from this checkout in an isolated Julia
environment. Their plotting dependencies are deliberately kept out of the
package's `Project.toml`, so installing BrowserPlots does not install or
precompile CairoMakie or Plots.jl.

From the repository root, install the example environment once:

```julia
julia --project=examples -e 'using Pkg; Pkg.instantiate()'
```

Then run either workflow:

```julia
julia --project=examples examples/makie.jl
julia --project=examples examples/plots.jl
```

Each script starts the gallery without opening a browser, displays one plot,
and verifies that BrowserPlots captured a PNG. They use port `8008` by default;
pass a different port as the sole argument if needed:

```julia
julia --project=examples examples/makie.jl 8010
```
