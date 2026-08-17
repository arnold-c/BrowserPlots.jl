module BrowserPlotsMakieExt

using Makie

function enable_inline!()
    Makie.inline!(true)
    return nothing
end

end
