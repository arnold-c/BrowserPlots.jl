using BrowserPlots
using Plots

const PNG_SIGNATURE = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

function check_gallery()
    history = BrowserPlots.VIEWER.history
    @assert length(history) == 1 "Expected one Plots.jl plot in the gallery."
    @assert history[1].data[1:8] == PNG_SIGNATURE "Plots.jl plot was not rendered as a PNG."
end

function main(port = 8010)
    BrowserPlots.clear_history!()
    BrowserPlots.browse(; port, silent = true)

    try
        plot(1:10, (1:10).^2; title = "BrowserPlots Plots.jl check") |> display

        check_gallery()
        println("Plots.jl workflow passed.")
    finally
        BrowserPlots.close_server!()
        BrowserPlots.clear_history!()
    end
end

main(isempty(ARGS) ? 8010 : parse(Int, only(ARGS)))
