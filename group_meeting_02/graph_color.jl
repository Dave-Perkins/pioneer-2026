# Usage: julia --project=. graph_color.jl graphs/graph01.txt

using GLMakie
using Random 

include("graph_color_utils.jl")

function check_proper_coloring(edges, colors)
    """ Returns true if the graph is properly colored. """
    for edge in edges
        if colors[edge[1]] == colors[edge[2]]
            return false
        end
    end
    return true
end

function greedy_coloring(edges, colors, n_colors)
    """ A greedy heuristic that assigns an available color that has been used the most so far. """
    all_colors = [n for n in 1:n_colors]
    # Store the frequency of the various colors in a dictionary
    color_frequencies = Dict{Int, Int}(x => 0 for x in 1:n_colors)
    color_frequencies[1] = length(colors) # all nodes have color 1 when we start
    # Put the nodes in a random order
    node_order = shuffle!([n for n in 1:length(colors)])
    @show node_order
    # Leave the first node with color 1, and iterate through the rest of the nodes
    for n in node_order[2:end]
        # Collect the neighbors of the node with label n 
        neighbors = [v for (u, v) ∈ edges if u == n]
        append!(neighbors, [u for (u, v) ∈ edges if v == n && u ∉ neighbors])
        # Collect the colors used by those neighbors 
        neighbors_colors = unique([colors[n] for n in neighbors])
        # Collect the colors that are NOT used by those neighbors  
        available_colors = setdiff(all_colors, neighbors_colors)
        # If no colors are available, then give up 
        if isempty(available_colors)
            println("I have failed to color this graph properly.")
            return 
        end
        # Choose the available color that has thus far been used the least 
        most_used_available_color = argmax(key -> color_frequencies[key], available_colors)
        # Assign that color to the current node
        color_frequencies[colors[n]] -= 1
        colors[n] = most_used_available_color
        color_frequencies[colors[n]] += 1
    end

end

if length(ARGS) < 1
    println("Usage: julia --project=. graph_color.jl <graph.txt>")
    exit(1)
end

path = ARGS[1]
isfile(path) || error("File not found: $path")

positions, colors, edges, n_colors = load_graph(path)
isempty(positions) && error("No vertices found in $path")

screen, o_colors, o_labels = display_graph(positions, edges, basename(path))
greedy_coloring(edges, colors, n_colors)
println("Properly colored: ", check_proper_coloring(edges, colors))
set_colors!(o_colors, o_labels, colors)
wait(screen)