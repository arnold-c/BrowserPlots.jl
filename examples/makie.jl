using BrowserPlots
# using CairoMakie
using GLMakie

const PNG_SIGNATURE = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

function check_gallery()
    history = BrowserPlots.VIEWER.history
    @assert length(history) == 1 "Expected one Makie plot in the gallery."
    @assert history[1].data[1:8] == PNG_SIGNATURE "Makie plot was not rendered as a PNG."
end

function main(port = 8010)
    BrowserPlots.clear_history!()
    BrowserPlots.browse(; port, silent = true)

    try
        x = range(0, 2π; length = 200)
        figure = Figure()
        axis = Axis(figure[1, 1]; title = "BrowserPlots Makie check")
        lines!(axis, x, sin.(x))
        display(figure)

        check_gallery()
        println("Makie workflow passed.")
    finally
        BrowserPlots.close_server!()
        BrowserPlots.clear_history!()
    end
end

main(isempty(ARGS) ? 8010 : parse(Int, only(ARGS)))
