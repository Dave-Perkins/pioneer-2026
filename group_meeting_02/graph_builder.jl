# First time only
# julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Launch
# julia --project=. graph_builder.jl
# julia --project=. graph_builder.jl -colors 3

using GLMakie
using LinearAlgebra
using Dates
using NativeFileDialog

# ── constants ──────────────────────────────────────────────────────────────

const NODE_R = 0.038f0   # hit-test radius in data-coordinate units

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

# ── application ────────────────────────────────────────────────────────────

function run_graph_builder(n_colors::Int = 8)
    palette = PALETTE[1:n_colors]

    # --- mutable graph state ---
    positions = Point2f[]
    col_idx   = Int[]
    edge_list = Tuple{Int,Int}[]

    # --- observables that drive the rendered plot ---
    o_pos    = Observable(Point2f[])
    o_colors = Observable(RGBf[])
    o_labels = Observable(String[])
    o_segs   = Observable(Point2f[])              # flattened pairs: [a1,b1, a2,b2, …]
    o_prev   = Observable([Point2f(0,0), Point2f(0,0)])  # drag-preview line
    o_pvis   = Observable(false)

    # --- layout ---
    fig = Figure(size = (820, 870), backgroundcolor = :white)

    Label(fig[1, 1],
          "Click empty → new node  │  Drag node→node → edge  │  Click node → cycle color";
          fontsize = 12, color = :gray50, tellwidth = false)

    btn_row   = fig[3, 1] = GridLayout(tellwidth = false)
    clear_btn = Button(btn_row[1, 1]; label = "Clear")
    save_btn  = Button(btn_row[1, 2]; label = "Save")
    load_btn  = Button(btn_row[1, 3]; label = "Load")

    ax = Axis(fig[2, 1]; aspect = DataAspect(), limits = (0, 1, 0, 1),
              xgridvisible = false, ygridvisible = false)
    hidedecorations!(ax)
    hidespines!(ax)

    # --- drawing layers (back → front) ---
    poly!(ax, Rect(0f0, 0f0, 1f0, 1f0);
          color = RGBf(0.97, 0.97, 0.97), strokecolor = :gray80, strokewidth = 1)

    linesegments!(ax, o_segs; color = (:gray30, 0.9), linewidth = 2.5)

    lines!(ax, o_prev; color = (:gray50, 0.5), linewidth = 1.5,
           linestyle = :dash, visible = o_pvis)

    scatter!(ax, o_pos; color = o_colors, markersize = 46,
             strokecolor = :white, strokewidth = 2.5)

    text!(ax, o_pos; text = o_labels, color = :white,
          align = (:center, :center), fontsize = 15, font = :bold)

    # --- helpers ---

    find_node(p) = findfirst(q -> norm(p - q) < NODE_R, positions)

    function sync!()
        o_pos[]    = copy(positions)
        o_colors[] = [palette[c] for c in col_idx]
        o_labels[] = string.(eachindex(positions))
        segs = Point2f[]
        for (u, v) in edge_list
            push!(segs, positions[u], positions[v])
        end
        o_segs[] = segs
    end

    # --- mouse interaction ---
    drag_node = Ref{Union{Int,Nothing}}(nothing)  # which node the drag started from

    on(save_btn.clicks) do _
        isempty(positions) && return

        isdir("graphs") || mkdir("graphs")

        # Next available graphNN.txt
        n_file = 1
        while isfile(joinpath("graphs", "graph$(lpad(n_file, 2, '0')).txt"))
            n_file += 1
        end
        path = joinpath("graphs", "graph$(lpad(n_file, 2, '0')).txt")

        # Build sorted adjacency lists
        nv  = length(positions)
        adj = [Int[] for _ in 1:nv]
        for (u, v) in edge_list
            push!(adj[u], v); push!(adj[v], u)
        end
        foreach(sort!, adj)

        # Format: vertex  x  y  color  neighbor1  neighbor2  ...
        # The header line is used by Load to detect this format.
        open(path, "w") do f
            println(f, "# graph_builder")
            println(f, "# colors $n_colors")
            println(f, "# vertex  x  y  color  neighbor1  neighbor2  ...")
            for i in 1:nv
                print(f, i, "  ",
                      round(Float64(positions[i][1]), digits = 4), "  ",
                      round(Float64(positions[i][2]), digits = 4), "  ",
                      col_idx[i])
                for nb in adj[i]; print(f, "  ", nb); end
                println(f)
            end
        end
        println("Saved → $path")
    end

    on(load_btn.clicks) do _
      @async begin
        path = pick_file(; filterlist = "txt")
        (path === nothing || isempty(path)) && return

        new_pos    = Point2f[]
        new_colors = Int[]
        new_edges  = Tuple{Int,Int}[]
        is_gb      = false   # true when file has graph_builder header

        for raw in eachline(path)
            line = strip(raw)
            isempty(line) && continue
            if startswith(line, "# graph_builder")
                is_gb = true; continue
            end
            startswith(line, "#") && continue

            toks = split(line)
            isempty(toks) && continue
            v = parse(Int, toks[1])

            while length(new_pos) < v          # expand to fit vertex index
                push!(new_pos,    Point2f(0.5, 0.5))
                push!(new_colors, 1)
            end

            if is_gb && length(toks) >= 4
                new_pos[v]    = Point2f(parse(Float32, toks[2]),
                                        parse(Float32, toks[3]))
                new_colors[v] = clamp(parse(Int, toks[4]), 1, n_colors)
                for tok in toks[5:end]
                    e = minmax(v, parse(Int, tok))
                    e ∉ new_edges && push!(new_edges, e)
                end
            else
                # Old adjacency-list format: positions unknown, lay out in a circle later
                for tok in toks[2:end]
                    e = minmax(v, parse(Int, tok))
                    e ∉ new_edges && push!(new_edges, e)
                end
            end
        end

        # For old-format files arrange nodes in a circle
        if !is_gb
            nv = length(new_pos)
            for i in 1:nv
                θ = 2π * (i - 1) / max(nv, 1) - π/2
                new_pos[i] = Point2f(0.5f0 + 0.35f0*cos(θ), 0.5f0 + 0.35f0*sin(θ))
            end
        end

        empty!(positions); append!(positions, new_pos)
        empty!(col_idx);   append!(col_idx,   new_colors)
        empty!(edge_list); append!(edge_list,  new_edges)
        drag_node[] = nothing
        o_pvis[]    = false
        sync!()
        println("Loaded ← $path")
      end  # @async begin
    end

    on(clear_btn.clicks) do _
        empty!(positions)
        empty!(col_idx)
        empty!(edge_list)
        drag_node[] = nothing
        o_pvis[]    = false
        sync!()
    end

    register_interaction!(ax, :graph_build) do event::MouseEvent, _
        p = Point2f(event.data)

        if event.type == MouseEventTypes.leftdown
            drag_node[] = find_node(p)
            if drag_node[] !== nothing
                o_prev[] = [positions[drag_node[]], p]
                o_pvis[] = true
            end

        elseif event.type == MouseEventTypes.leftdrag
            if drag_node[] !== nothing
                o_prev[] = [positions[drag_node[]], p]
            end

        elseif event.type == MouseEventTypes.leftdragstop
            o_pvis[] = false
            if drag_node[] !== nothing
                hit = find_node(p)
                if hit !== nothing && hit != drag_node[]
                    e = minmax(drag_node[], hit)   # canonical (lo, hi) form
                    e ∉ edge_list && push!(edge_list, e)
                    sync!()
                end
            end
            drag_node[] = nothing

        elseif event.type == MouseEventTypes.leftclick
            hit = find_node(p)
            if hit !== nothing
                col_idx[hit] = mod1(col_idx[hit] + 1, n_colors)
            else
                push!(positions, p)
                push!(col_idx, 1)
            end
            sync!()
        end

        Consume(true)   # prevent axis pan/zoom from interfering
    end

    screen = display(fig)
    wait(screen)
end

n_colors = 8
idx = findfirst(==("-colors"), ARGS)
if idx !== nothing && idx + 1 <= length(ARGS)
    n_colors = parse(Int, ARGS[idx + 1])
    @assert 1 <= n_colors <= length(PALETTE) "-colors must be between 1 and $(length(PALETTE))"
end

run_graph_builder(n_colors)
