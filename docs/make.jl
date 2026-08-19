using BrowserPlots
using Documenter
using DocumenterVitepress

makedocs(;
    modules = [BrowserPlots],
    authors = "Callum Arnold",
    sitename = "BrowserPlots.jl",
    format = DocumenterVitepress.MarkdownVitepress(
        repo = "github.com/arnold-c/BrowserPlots.jl",
        devbranch = "main",
        devurl = "dev",
        deploy_url = "https://browserplots.callumarnold.com"
    ),
    pages = ["Home" => "index.md"],
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/arnold-c/BrowserPlots.jl",
    target = joinpath(@__DIR__, "build"),
    branch = "docs-page",
    devbranch = "main",
    push_preview = true,
)
