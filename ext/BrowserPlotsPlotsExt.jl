module BrowserPlotsPlotsExt

using BrowserPlots
using Plots

function Base.display(browser_display::BrowserPlots.BrowserDisplay, plot::Plots.Plot)
    return Base.display(browser_display, MIME"image/png"(), plot)
end

end
