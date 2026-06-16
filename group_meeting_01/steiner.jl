using Plots
using Statistics

include("utils.jl")

function create(n::Int, m::Int)
    """ Choose m points in an n by n lattice.
        The lower left corner is (0, 0) and upper right (n, n). """
    points = Tuple{Int, Int}[]
    while length(points) < m  
        point = (rand(0:n), rand(0:n))
        if !(point in points)
            push!(points, point)
        end
    end
    return points
end

function run_MSTST(plt, x_coords, y_coords, marker_size, points::Vector{Tuple{Int, Int}}, board_dimension::Int)
    y_median = Int(round(median([p[2] for p in points])))
    Plots.plot!(plt, [0, board_dimension], [y_median, y_median], color=:red, linewidth=3, alpha=0.9, label="")

    score = board_dimension # for the horizontal median line

    # Determine the vertical segments extending from the median line
    for x in 0:board_dimension
        valid_points = [p for p in points if p[1] == x]
        if !isempty(valid_points)
            above_y = [p[2] for p in valid_points if p[2] >= y_median]
            if !isempty(above_y)
                max_y = maximum(above_y)
                score += (max_y - y_median)
                Plots.plot!(plt, [x, x], [y_median, max_y], color=:red, linewidth=3, alpha=0.9, label="")
            end
            below_y = [p[2] for p in valid_points if p[2] <= y_median]
            if !isempty(below_y)
                min_y = minimum(below_y)
                score += (y_median - min_y)
                Plots.plot!(plt, [x, x], [y_median, min_y], color=:red, linewidth=3, alpha=0.9, label="")
            end
        end
    end
    
    # Add purple points last so they're on top
    Plots.scatter!(plt, x_coords, y_coords, color=:purple, markerstrokewidth=0, markersize=marker_size, label="")
    
    println("score is ", score)
end

# Main execution
if length(ARGS) > 0
    board_dimension = parse(Int, ARGS[1])
    num_points = parse(Int, ARGS[2])
    mode = length(ARGS) > 2 ? lowercase(ARGS[3]) : "default"
    
    if mode == "save"
        save_flag = true
        points = nothing
    elseif mode == "read"
        filename = ARGS[4]
        points = load_points(filename)
        # Determine board_dimension from the loaded points
        if !isempty(points)
            board_dimension = max(maximum([p[1] for p in points]), maximum([p[2] for p in points]))
        end
        num_points = length(points)
        save_flag = false
    else
        save_flag = false
        points = nothing
    end
else
    # Default values if no args provided
    board_dimension = 5
    num_points = 10
    save_flag = false
    points = nothing
end

# Only create new points if we didn't load them
if points === nothing
    clear_terminal()
    points = create(board_dimension, num_points)
    read_mode = false
else
    clear_terminal()
    read_mode = true
end
plt, x_coords, y_coords, marker_size = plot_points(points, board_dimension, true)
run_MSTST(plt, x_coords, y_coords, marker_size, points, board_dimension)

# Display if running interactively, or if in read mode
if isinteractive() || read_mode
    display(plt)
end

if save_flag
    # Save both plot and points with matching numbers
    plot_num, plot_filename = get_next_plot_filename()
    points_num, points_filename = get_next_points_filename()
    
    # Ensure they have the same number
    if plot_num != points_num
        # Adjust to use the same number
        points_filename = joinpath("steiner_points", "points_$(lpad(plot_num, 2, '0')).txt")
    end
    
    savefig(plt, plot_filename)
    save_points(points, points_filename)
    println("Plot saved to $plot_filename")
    println("points saved to $points_filename")
elseif read_mode
    # When reading, also save the plot
    plot_filename = "steiner_plots/read_mode_plot.png"
    savefig(plt, plot_filename)
    println("Plot saved to $plot_filename")
end
