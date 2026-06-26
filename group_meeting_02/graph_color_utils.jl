# Reads graph_builder's save format:
#   # graph_builder
#   # vertex  x  y  color  neighbor1  neighbor2  ...
#   1  0.312  0.487  1  2  3
#
# Falls back to plain adjacency-list format (positions arranged in a circle).

function load_graph(path::String)
    positions = Point2f[]
    colors    = Int[]
    edges     = Tuple{Int,Int}[]
    is_gb     = false
    n_colors  = 8

    for raw in eachline(path)
        line = strip(raw)
        isempty(line) && continue
        if startswith(line, "# graph_builder")
            is_gb = true; continue
        end
        if startswith(line, "# colors ")
            n_colors = parse(Int, split(line)[3]); continue
        end
        startswith(line, "#") && continue

        toks = split(line)
        isempty(toks) && continue
        v = parse(Int, toks[1])

        while length(positions) < v
            push!(positions, Point2f(0.5, 0.5))
            push!(colors, 1)
        end

        if is_gb && length(toks) >= 4
            positions[v] = Point2f(parse(Float32, toks[2]), parse(Float32, toks[3]))
            # colors[v]    = parse(Int, toks[4])
            for tok in toks[5:end]
                e = minmax(v, parse(Int, tok))
                e ∉ edges && push!(edges, e)
            end
        else
            for tok in toks[2:end]
                e = minmax(v, parse(Int, tok))
                e ∉ edges && push!(edges, e)
            end
        end
    end

    if !is_gb
        n = length(positions)
        for i in 1:n
            θ = 2π * (i - 1) / max(n, 1) - π/2
            positions[i] = Point2f(0.5f0 + 0.35f0*cos(θ), 0.5f0 + 0.35f0*sin(θ))
        end
    end

    return positions, colors, edges, n_colors
end

const PALETTE = [
    RGBf(0.306, 0.475, 0.654),   # ① blue
    RGBf(0.945, 0.557, 0.169),   # ② orange
    RGBf(0.882, 0.341, 0.349),   # ③ red
    RGBf(0.349, 0.631, 0.310),   # ④ green
    RGBf(0.463, 0.718, 0.698),   # ⑤ teal
    RGBf(0.929, 0.788, 0.282),   # ⑥ yellow
    RGBf(0.690, 0.478, 0.631),   # ⑦ purple
    RGBf(1.000, 0.616, 0.655),   # ⑧ pink
]

function display_graph(positions::Vector{Point2f}, edges::Vector{Tuple{Int,Int}},
                       title::String = "")
    segs = Point2f[]
    for (u, v) in edges
        push!(segs, positions[u], positions[v])
    end

    n        = length(positions)
    o_colors = Observable(fill(RGBf(1, 1, 1), n))   # all white initially
    o_labels = Observable(fill(:black, n))            # all black initially

    fig = Figure(size = (800, 800), backgroundcolor = :white)
    ax  = Axis(fig[1, 1];
               aspect       = DataAspect(),
               limits       = (0, 1, 0, 1),
               title        = title,
               xgridvisible = false,
               ygridvisible = false)
    hidedecorations!(ax)
    hidespines!(ax)

    poly!(ax, Rect(0f0, 0f0, 1f0, 1f0);
          color = RGBf(0.97, 0.97, 0.97), strokecolor = :gray80, strokewidth = 1)

    isempty(segs) || linesegments!(ax, segs; color = (:gray40, 0.9), linewidth = 2.5)

    scatter!(ax, positions;
             color       = o_colors,
             markersize  = 46,
             strokecolor = :gray20,
             strokewidth = 2.5)

    text!(ax, positions;
          text     = string.(eachindex(positions)),
          color    = o_labels,
          align    = (:center, :center),
          fontsize = 15,
          font     = :bold)

    return display(fig), o_colors, o_labels
end

# Call this after your coloring algorithm to update the display.
# color_indices is a Vector{Int} with values in 1:8, one per vertex.
function set_colors!(o_colors, o_labels, color_indices)
    o_colors[] = [PALETTE[c] for c in color_indices]
    o_labels[] = fill(:white, length(color_indices))
end
