module BrowserPlotsPlotsExt

using BrowserPlots
using Plots

function disable_auto_show!()
    Plots.default(show = false)
    # GR reads these when it creates a workstation. A PNG workstation avoids
    # launching gksqt while BrowserPlots renders the plot into an IOBuffer.
    ENV["GKSwstype"] = "100"
    ENV["GKS_WSTYPE"] = "100"
    return nothing
end

function __init__()
    BrowserPlots.VIEWER.active && disable_auto_show!()
    return nothing
end

function Base.display(browser_display::BrowserPlots.BrowserDisplay, plot::Plots.Plot)
    return Base.display(browser_display, MIME"image/png"(), plot)
end

end
