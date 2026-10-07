module BrowserPlotsIJuliaExt

using BrowserPlots
using IJulia

# IJulia builds the frontend output from these lists after the post-execute
# hooks run. Emptying them for one cell suppresses the inline output.
const SAVED_MIME_TYPES = Ref{Union{Nothing, Tuple}}(nothing)

function suppress_inline!()
    isnothing(SAVED_MIME_TYPES[]) || return nothing
    SAVED_MIME_TYPES[] = (copy(IJulia.ijulia_mime_types), copy(IJulia.ijulia_jsonmime_types))
    empty!(IJulia.ijulia_mime_types)
    empty!(IJulia.ijulia_jsonmime_types)
    return nothing
end

function restore_inline!()
    saved = SAVED_MIME_TYPES[]
    isnothing(saved) && return nothing
    append!(IJulia.ijulia_mime_types, saved[1])
    append!(IJulia.ijulia_jsonmime_types, saved[2])
    SAVED_MIME_TYPES[] = nothing
    return nothing
end

# Forward the final value of an IJulia cell to the gallery. IJulia sends it to
# the frontend without going through the display stack.
function forward_result()
    try
        value = IJulia.ans
        isnothing(value) && return nothing
        # Out[n] is only set when IJulia shows the value (no trailing `;`).
        get(IJulia.Out, IJulia.n, nothing) === value || return nothing
        BrowserPlots.gallery_displayable(value) || return nothing
        if !(objectid(value) in BrowserPlots.VIEWER.displayed)
            BrowserPlots.add_to_gallery!(value)
        end
        BrowserPlots.KERNEL_INLINE[] || suppress_inline!()
    catch err
        @warn "BrowserPlots: failed to forward IJulia result" exception = err
    end
    return nothing
end

function reset_cell()
    restore_inline!()
    BrowserPlots.reset_displayed!()
    return nothing
end

function BrowserPlots._register_kernel_hooks(kernel::BrowserPlots.IJuliaKernel)
    IJulia.inited || return nothing
    BrowserPlots._unregister_kernel_hooks(kernel)
    IJulia.push_preexecute_hook(reset_cell)
    IJulia.push_postexecute_hook(forward_result)
    return nothing
end

function BrowserPlots._unregister_kernel_hooks(::BrowserPlots.IJuliaKernel)
    IJulia.inited || return nothing
    restore_inline!()
    try
        IJulia.pop_preexecute_hook(reset_cell)
    catch
    end
    try
        IJulia.pop_postexecute_hook(forward_result)
    catch
    end
    return nothing
end

end
