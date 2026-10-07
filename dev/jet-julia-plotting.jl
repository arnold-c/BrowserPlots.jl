#%%
using BrowserPlots
using CairoMakie

#%%
BrowserPlots.browse(; port = 8020, ijulia = true, inline = true)
lines(1:0.1:10, sin.(1:0.1:10); color = "blue")

#%%
BrowserPlots.browse(; port = 8020, silent = true, ijulia = true, inline = false)
lines(1:0.1:10, sin.(1:0.1:10); color = "red")

#%%
BrowserPlots.browse(; port = 8020, silent = true, ijulia = true, inline = true)
lines(1:0.1:10, sin.(1:0.1:10); color = "green")
