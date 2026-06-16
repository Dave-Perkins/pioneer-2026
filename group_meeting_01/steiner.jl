# import Pkg
# Pkg.add("Plots")
# Pkg.add("Statistics")
using Plots
using Statistics

function clear_terminal()
    if Sys.iswindows()
        run(`cls`)
    else
        println("\033[2J")
        run(`clear`)
    end
end

function create(n::Int, m::Int)
    """ Choose m points in an n by n lattice.
        The lower left corner is (0, 0) and upper right (n, n). """
    vertices = Tuple{Int, Int}[]
    while length(vertices) < m  
        vertex = (rand(0:n), rand(0:n))
        if !(vertex in vertices)
            push!(vertices, vertex)
        end
    end
    return vertices
end

function plot_points(points::Vector{Tuple{Int, Int}}, n::Int, add_points::Bool=true)
    """ Plot an array of tuples as points on a first quadrant graph.
        n is the size of the grid. """
    x_coords = [p[1] for p in points]
    y_coords = [p[2] for p in points]
    
    # Scale marker size based on board dimension
    marker_size = max(3, 8 - div(n, 5))
    
    # Create empty plot
    plt = Plots.plot(xlim=(-1, n + 1), 
         ylim=(-1, n + 1),
         xlabel="",
         ylabel="",
         title="",
         legend=false,
         grid=true,
         aspect_ratio=:equal,
         xticks=0:n+1,
         yticks=0:n+1)
    
    # Add horizontal lines for each point's y-coordinate (from x=1 to x=n)
    for y in unique(y_coords)
        Plots.plot!(plt, [0, n], [y, y], color=:green, alpha=0.5, label="")
    end
    # Add vertical lines for each point's x-coordinate (from y=1 to y=n)
    for x in unique(x_coords)
        Plots.plot!(plt, [x, x], [0, n], color=:green, alpha=0.5, label="")
    end
    
    # Draw square from (0,0) to (n,n)
    square_x = [0, n, n, 0, 0]
    square_y = [0, 0, n, n, 0]
    Plots.plot!(plt, square_x, square_y, color=:black, linewidth=3, label="")
    
    # Add points if requested
    if add_points
        Plots.scatter!(plt, x_coords, y_coords, color=:purple, markerstrokewidth=0, markersize=marker_size, label="")
    end
    
    return plt, x_coords, y_coords, marker_size
end

function run_MSTST(plt, x_coords, y_coords, marker_size, vertices::Vector{Tuple{Int, Int}}, board_dimension::Int)
    y_median = Int(round(median([p[2] for p in vertices])))
    Plots.plot!(plt, [0, board_dimension], [y_median, y_median], color=:red, linewidth=3, alpha=0.9, label="")

    score = board_dimension # for the horizontal median line

    # Determine the vertical segments extending from the median line
    for x in 0:board_dimension
        valid_points = [p for p in vertices if p[1] == x]
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

function save_vertices(vertices::Vector{Tuple{Int, Int}}, filename::String)
    """ Save vertices to a text file. Each line contains: x y """
    open(filename, "w") do file
        for (x, y) in vertices
            write(file, "$x $y\n")
        end
    end
    println("Vertices saved to $filename")
end

function load_vertices(filename::String)
    """ Load vertices from a text file. Each line should contain: x y """
    vertices = Tuple{Int, Int}[]
    open(filename, "r") do file
        for line in eachline(file)
            parts = split(strip(line))
            if length(parts) == 2
                x = parse(Int, parts[1])
                y = parse(Int, parts[2])
                push!(vertices, (x, y))
            end
        end
    end
    println("Loaded $(length(vertices)) vertices from $filename")
    return vertices
end

function get_next_plot_filename()
    """ Generate next numbered plot filename in steiner_plots folder """
    folder = "steiner_plots"
    
    # Create folder if it doesn't exist
    if !isdir(folder)
        mkdir(folder)
    end
    
    # Find the highest existing number
    max_num = 0
    for file in readdir(folder)
        if startswith(file, "plot_output_") && endswith(file, ".png")
            # Extract number from filename
            num_str = replace(file, "plot_output_" => "", ".png" => "")
            try
                num = parse(Int, num_str)
                max_num = max(max_num, num)
            catch
                # Skip files that don't match the pattern
            end
        end
    end
    
    next_num = max_num + 1
    return next_num, joinpath(folder, "plot_output_$(lpad(next_num, 2, '0')).png")
end

function get_next_vertices_filename()
    """ Generate next numbered vertices filename in steiner_vertices folder """
    folder = "steiner_vertices"
    
    # Create folder if it doesn't exist
    if !isdir(folder)
        mkdir(folder)
    end
    
    # Find the highest existing number
    max_num = 0
    for file in readdir(folder)
        if startswith(file, "vertices_") && endswith(file, ".txt")
            # Extract number from filename
            num_str = replace(file, "vertices_" => "", ".txt" => "")
            try
                num = parse(Int, num_str)
                max_num = max(max_num, num)
            catch
                # Skip files that don't match the pattern
            end
        end
    end
    
    next_num = max_num + 1
    return next_num, joinpath(folder, "vertices_$(lpad(next_num, 2, '0')).txt")
end

function open_plot(filename::String)
    """ Open a plot file in the default image viewer """
    if Sys.isapple()
        run(`open $filename`)
    elseif Sys.iswindows()
        run(`start $filename`)
    elseif Sys.islinux()
        run(`xdg-open $filename`)
    else
        println("Could not open $filename on this system")
    end
end

# Main execution
if length(ARGS) > 0
    board_dimension = parse(Int, ARGS[1])
    num_vertices = parse(Int, ARGS[2])
    mode = length(ARGS) > 2 ? lowercase(ARGS[3]) : "default"
    
    if mode == "save"
        save_flag = true
        vertices = nothing
    elseif mode == "read"
        filename = ARGS[4]
        vertices = load_vertices(filename)
        # Determine board_dimension from the loaded vertices
        if !isempty(vertices)
            board_dimension = max(maximum([p[1] for p in vertices]), maximum([p[2] for p in vertices]))
        end
        num_vertices = length(vertices)
        save_flag = false
    else
        save_flag = false
        vertices = nothing
    end
else
    # Default values if no args provided
    board_dimension = 5
    num_vertices = 10
    save_flag = false
    vertices = nothing
end

# Only create new vertices if we didn't load them
if vertices === nothing
    clear_terminal()
    vertices = create(board_dimension, num_vertices)
    read_mode = false
else
    clear_terminal()
    read_mode = true
end
plt, x_coords, y_coords, marker_size = plot_points(vertices, board_dimension, true)
run_MSTST(plt, x_coords, y_coords, marker_size, vertices, board_dimension)

# Display if running interactively, or if in read mode
if isinteractive() || read_mode
    display(plt)
end

if save_flag
    # Save both plot and vertices with matching numbers
    plot_num, plot_filename = get_next_plot_filename()
    vertices_num, vertices_filename = get_next_vertices_filename()
    
    # Ensure they have the same number
    if plot_num != vertices_num
        # Adjust to use the same number
        vertices_filename = joinpath("steiner_vertices", "vertices_$(lpad(plot_num, 2, '0')).txt")
    end
    
    savefig(plt, plot_filename)
    save_vertices(vertices, vertices_filename)
    println("Plot saved to $plot_filename")
    println("Vertices saved to $vertices_filename")
elseif read_mode
    # When reading, also save the plot
    plot_filename = "steiner_plots/read_mode_plot.png"
    savefig(plt, plot_filename)
    println("Plot saved to $plot_filename")
end
