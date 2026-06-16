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

function save_points(points::Vector{Tuple{Int, Int}}, filename::String)
    """ Save points to a text file. Each line contains: x y """
    open(filename, "w") do file
        for (x, y) in points
            write(file, "$x $y\n")
        end
    end
    println("points saved to $filename")
end

function load_points(filename::String)
    """ Load points from a text file. Each line should contain: x y """
    points = Tuple{Int, Int}[]
    open(filename, "r") do file
        for line in eachline(file)
            parts = split(strip(line))
            if length(parts) == 2
                x = parse(Int, parts[1])
                y = parse(Int, parts[2])
                push!(points, (x, y))
            end
        end
    end
    println("Loaded $(length(points)) points from $filename")
    return points
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

function get_next_points_filename()
    """ Generate next numbered points filename in steiner_points folder """
    folder = "steiner_points"
    
    # Create folder if it doesn't exist
    if !isdir(folder)
        mkdir(folder)
    end
    
    # Find the highest existing number
    max_num = 0
    for file in readdir(folder)
        if startswith(file, "points_") && endswith(file, ".txt")
            # Extract number from filename
            num_str = replace(file, "points_" => "", ".txt" => "")
            try
                num = parse(Int, num_str)
                max_num = max(max_num, num)
            catch
                # Skip files that don't match the pattern
            end
        end
    end
    
    next_num = max_num + 1
    return next_num, joinpath(folder, "points_$(lpad(next_num, 2, '0')).txt")
end
