module BrowserPlots

using HTTP
using Dates

export browse, clear_history!, close_server!

struct PlotEntry
    id::Int
    data::Vector{UInt8}
    timestamp::String
end

mutable struct BrowserDisplay <: AbstractDisplay
    history::Vector{PlotEntry}
    server::Union{HTTP.Server, Nothing}
    port::Int
    active::Bool
    next_id::Int
end

const VIEWER = BrowserDisplay(PlotEntry[], nothing, 8008, false, 1)

const HTML_VIEWER_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>BrowserGraphics Viewer</title>
  <style>
    :root {
      --bg-dark: #121212;
      --bg-panel: #1e1e1e;
      --bg-card: #282828;
      --accent: #3b82f6;
      --text-main: #f3f4f6;
      --text-muted: #9ca3af;
      --border: #374151;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg-dark); color: var(--text-main); height: 100vh; display: flex; flex-direction: column; overflow: hidden; }
    header { background: var(--bg-panel); border-bottom: 1px solid var(--border); padding: 10px 20px; display: flex; justify-content: space-between; align-items: center; }
    .logo-group { display: flex; align-items: center; gap: 12px; }
    .counter { font-weight: 600; color: var(--accent); background: rgba(59, 130, 246, 0.15); padding: 4px 10px; border-radius: 999px; font-size: 0.85rem; }
    .btn-group { display: flex; gap: 8px; }
    button { background: var(--bg-card); color: var(--text-main); border: 1px solid var(--border); padding: 6px 14px; border-radius: 6px; cursor: pointer; font-size: 0.85rem; transition: all 0.2s; }
    button:hover { background: #333; border-color: var(--accent); }
    button.active { background: var(--accent); border-color: var(--accent); color: white; }
    #workspace { flex: 1; display: flex; overflow: hidden; }
    #sidebar { width: 280px; background: var(--bg-panel); border-right: 1px solid var(--border); display: flex; flex-direction: column; overflow-y: auto; }
    .sidebar-header { padding: 12px 16px; font-size: 0.8rem; font-weight: 600; text-transform: uppercase; color: var(--text-muted); border-bottom: 1px solid var(--border); }
    .thumb-list { display: flex; flex-direction: column; gap: 10px; padding: 12px; }
    .thumb-card { background: var(--bg-card); border: 2px solid transparent; border-radius: 6px; padding: 8px; cursor: pointer; transition: all 0.15s ease; }
    .thumb-card:hover { border-color: #555; }
    .thumb-card.selected { border-color: var(--accent); background: #2f3542; }
    .thumb-card img { width: 100%; height: 110px; object-fit: contain; background: white; border-radius: 4px; display: block; }
    .thumb-meta { display: flex; justify-content: space-between; align-items: center; margin-top: 6px; font-size: 0.75rem; color: var(--text-muted); }
    .delete-btn { padding: 1px 7px; color: var(--text-muted); border-color: transparent; font-size: 1rem; line-height: 1.2; }
    .delete-btn:hover { color: #f87171; border-color: #f87171; background: rgba(248, 113, 113, 0.1); }
    #focus-view { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 24px; position: relative; }
    #focus-image { max-width: 100%; max-height: 80vh; object-fit: contain; background: white; border-radius: 8px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
    .nav-overlay { margin-top: 14px; display: flex; gap: 10px; align-items: center; }
    #grid-view { flex: 1; padding: 20px; overflow-y: auto; display: none; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 20px; align-content: flex-start; }
    .grid-card { background: var(--bg-panel); border: 1px solid var(--border); border-radius: 8px; padding: 12px; display: flex; flex-direction: column; gap: 8px; cursor: pointer; transition: transform 0.15s; }
    .grid-card:hover { transform: translateY(-2px); border-color: var(--accent); }
    .grid-card img { width: 100%; height: 220px; object-fit: contain; background: white; border-radius: 6px; }
    .empty-state { margin: auto; text-align: center; color: var(--text-muted); }
  </style>
</head>
<body>
  <header>
    <div class="logo-group">
      <strong>BrowserGraphics</strong>
      <span id="plot-counter" class="counter">0 Plots</span>
    </div>
    <div class="btn-group">
      <button id="btn-focus" class="active" onclick="setViewMode('focus')">Split View</button>
      <button id="btn-grid" onclick="setViewMode('grid')">Grid View</button>
      <button onclick="clearHistory()">Clear</button>
    </div>
  </header>

  <div id="workspace">
    <div id="sidebar">
      <div class="sidebar-header">Session History</div>
      <div class="thumb-list" id="thumb-list"></div>
    </div>
    <div id="focus-view">
      <div id="empty-focus" class="empty-state">No plots generated yet.<br>Execute any Makie/Plots call in Neovim.</div>
      <img id="focus-image" style="display:none;" />
      <div class="nav-overlay" id="nav-overlay" style="display:none;">
        <button onclick="navigate(-1)">← Prev</button>
        <span id="focus-indicator" style="font-size: 0.85rem; color: var(--text-muted);">0 / 0</span>
        <button onclick="navigate(1)">Next →</button>
      </div>
    </div>
    <div id="grid-view"></div>
  </div>

  <script>
    let plotList = [];
    let currentIndex = -1;
    let viewMode = 'focus';

    async function syncPlots() {
      const res = await fetch('/api/plots');
      const data = await res.json();
      const changed = data.length !== plotList.length ||
        data.some((plot, idx) => plot.id !== plotList[idx]?.id);
      if (!changed) return;

      const selectedId = plotList[currentIndex]?.id;
      const wasAtEnd = currentIndex === plotList.length - 1;
      plotList = data;
      renderGallery();

      if (plotList.length === 0) {
        showEmptyState();
      } else {
        const selectedIndex = plotList.findIndex(plot => plot.id === selectedId);
        selectPlot(wasAtEnd || selectedIndex < 0 ? plotList.length - 1 : selectedIndex);
      }
    }

    function renderGallery() {
      document.getElementById('plot-counter').innerText = plotList.length + ' Plot' + (plotList.length === 1 ? '' : 's');
      const thumbContainer = document.getElementById('thumb-list');
      const gridContainer = document.getElementById('grid-view');
      thumbContainer.innerHTML = '';
      gridContainer.innerHTML = '';

      plotList.forEach((plot, idx) => {
        const card = document.createElement('div');
        card.className = 'thumb-card' + (idx === currentIndex ? ' selected' : '');
        card.onclick = () => selectPlot(idx);
        card.innerHTML = `
          <img src="/plot/\${plot.id}" loading="lazy" />
          <div class="thumb-meta">
            <span>#\${plot.id} · \${plot.time}</span>
            <button class="delete-btn" title="Delete plot" onclick="deletePlot(\${plot.id}, event)">×</button>
          </div>
        `;
        thumbContainer.appendChild(card);

        const gridCard = document.createElement('div');
        gridCard.className = 'grid-card';
        gridCard.onclick = () => { selectPlot(idx); setViewMode('focus'); };
        gridCard.innerHTML = `
          <img src="/plot/\${plot.id}" loading="lazy" />
          <div class="thumb-meta">
            <span>#\${plot.id} · \${plot.time}</span>
            <button class="delete-btn" title="Delete plot" onclick="deletePlot(\${plot.id}, event)">×</button>
          </div>
        `;
        gridContainer.appendChild(gridCard);
      });
    }

    function selectPlot(idx) {
      if (idx < 0 || idx >= plotList.length) return;
      currentIndex = idx;
      document.getElementById('empty-focus').style.display = 'none';
      const img = document.getElementById('focus-image');
      img.src = '/plot/' + plotList[currentIndex].id;
      img.style.display = 'block';
      document.getElementById('nav-overlay').style.display = 'flex';
      document.getElementById('focus-indicator').innerText = (currentIndex + 1) + ' / ' + plotList.length;
      document.querySelectorAll('.thumb-card').forEach((el, i) => {
        el.classList.toggle('selected', i === currentIndex);
      });
    }

    function navigate(direction) { selectPlot(currentIndex + direction); }

    function setViewMode(mode) {
      viewMode = mode;
      document.getElementById('btn-focus').classList.toggle('active', mode === 'focus');
      document.getElementById('btn-grid').classList.toggle('active', mode === 'grid');
      document.getElementById('sidebar').style.display = mode === 'focus' ? 'flex' : 'none';
      document.getElementById('focus-view').style.display = mode === 'focus' ? 'flex' : 'none';
      document.getElementById('grid-view').style.display = mode === 'grid' ? 'grid' : 'none';
    }

    function showEmptyState() {
      currentIndex = -1;
      document.getElementById('focus-image').style.display = 'none';
      document.getElementById('nav-overlay').style.display = 'none';
      document.getElementById('empty-focus').style.display = 'block';
    }

    async function deletePlot(id, event) {
      event.stopPropagation();
      const selectedId = plotList[currentIndex]?.id;
      const deletedIndex = plotList.findIndex(plot => plot.id === id);
      const res = await fetch('/api/plots/' + id, { method: 'DELETE' });
      if (!res.ok) return;

      plotList = plotList.filter(plot => plot.id !== id);
      renderGallery();
      if (plotList.length === 0) {
        showEmptyState();
        return;
      }

      const selectedIndex = plotList.findIndex(plot => plot.id === selectedId);
      const nextIndex = selectedIndex >= 0 ? selectedIndex : Math.min(deletedIndex, plotList.length - 1);
      selectPlot(nextIndex);
    }

    async function clearHistory() {
      await fetch('/api/clear', { method: 'POST' });
      plotList = [];
      renderGallery();
      showEmptyState();
    }

    window.addEventListener('keydown', (e) => {
      if (viewMode === 'focus') {
        if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') navigate(-1);
        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') navigate(1);
      }
    });

    setInterval(syncPlots, 500);
  </script>
</body>
</html>
"""

function enable_makie_inline!()
    extension_module = Base.get_extension(@__MODULE__, :BrowserPlotsMakieExt)
    isnothing(extension_module) || extension_module.enable_inline!()
    return nothing
end

function open_browser(url::String)
    try
        if Sys.isapple()
            run(`open $url`, wait = false)
        elseif Sys.islinux()
            run(`xdg-open $url`, wait = false)
        elseif Sys.iswindows()
            run(`cmd /c start $url`, wait = false)
        end
    catch
        # Ignore failure to auto-launch browser
    end
end

"""
    browse(; port=8008, launch=true)

Starts the BrowserGraphics HTTP server, hooks into Julia's display system,
and optionally opens the browser gallery.
"""
function browse(; port::Int = 8008, launch::Bool = true)
    if VIEWER.server !== nothing
        close_server!()
    end

    VIEWER.port = port

    router = HTTP.Router()
    HTTP.register!(
        router,
        "GET",
        "/",
        r -> HTTP.Response(200, ["Content-Type" => "text/html"], HTML_VIEWER_TEMPLATE),
    )

    HTTP.register!(
        router,
        "GET",
        "/api/plots",
        r -> begin
            meta = [
                "{\"id\": $(p.id), \"time\": \"$(p.timestamp)\"}"
                for p in VIEWER.history
            ]
            HTTP.Response(
                200,
                ["Content-Type" => "application/json"],
                "[" * join(meta, ",") * "]",
            )
        end,
    )

    HTTP.register!(
        router,
        "POST",
        "/api/clear",
        r -> begin
            empty!(VIEWER.history)
            HTTP.Response(200, "OK")
        end,
    )

    HTTP.register!(
        router,
        "DELETE",
        "/api/plots/{id}",
        r -> begin
            id = parse(Int, HTTP.getparams(r)["id"])
            idx = findfirst(p -> p.id == id, VIEWER.history)
            if isnothing(idx)
                HTTP.Response(404, "Plot not found")
            else
                deleteat!(VIEWER.history, idx)
                HTTP.Response(200, "OK")
            end
        end,
    )

    HTTP.register!(
        router,
        "GET",
        "/plot/{id}",
        r -> begin
            id = parse(Int, HTTP.getparams(r)["id"])
            idx = findfirst(p -> p.id == id, VIEWER.history)
            if idx !== nothing
                HTTP.Response(
                    200,
                    ["Content-Type" => "image/png"],
                    VIEWER.history[idx].data,
                )
            else
                HTTP.Response(404, "Plot not found")
            end
        end,
    )

    VIEWER.server = HTTP.serve!(router, "127.0.0.1", port)

    if !VIEWER.active
        Base.pushdisplay(VIEWER)
        VIEWER.active = true
    end
    enable_makie_inline!()

    url = "http://127.0.0.1:$port"
    println("BrowserGraphics active at: $url")
    if launch
        open_browser(url)
    end
    return nothing
end

function clear_history!()
    empty!(VIEWER.history)
    return nothing
end

function close_server!()
    if VIEWER.server !== nothing
        close(VIEWER.server)
        VIEWER.server = nothing
    end
    if VIEWER.active
        try
            Base.popdisplay(VIEWER)
        catch
        end
        VIEWER.active = false
    end
    return nothing
end

Base.displayable(::BrowserDisplay, ::MIME"image/png") = true

function Base.display(d::BrowserDisplay, mime::MIME"image/png", x)
    io = IOBuffer()
    show(io, mime, x)
    entry = PlotEntry(d.next_id, take!(io), Dates.format(now(), "HH:MM:SS"))
    d.next_id += 1
    push!(d.history, entry)
    return nothing
end

function Base.display(d::BrowserDisplay, x)
    mime = MIME"image/png"()
    showable(mime, x) || throw(MethodError(display, (d, x)))
    return display(d, mime, x)
end

end # module
