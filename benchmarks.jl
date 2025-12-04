using BenchmarkTools
using CairoMakie
using BSON
using Dates
include("main.jl")

# Get current git SHA
function get_git_sha()
    try
        sha = strip(read(`git rev-parse --short HEAD`, String))
        return sha
    catch
        return "unknown"
    end
end

# Get benchmark filename based on date and git SHA
function get_benchmark_filename()
    date_str = Dates.format(Dates.today(), "yyyy-mm-dd")
    sha = get_git_sha()
    benchmarks_dir = "benchmarks"
    
    # Create benchmarks directory if it doesn't exist
    if !isdir(benchmarks_dir)
        mkdir(benchmarks_dir)
    end
    
    return joinpath(benchmarks_dir, "$(date_str)_$(sha).bson")
end

# Find existing benchmark file by git SHA
function find_benchmark_by_sha()
    sha = get_git_sha()
    benchmarks_dir = "benchmarks"
    
    if !isdir(benchmarks_dir)
        return nothing
    end
    
    # Look for any file with this SHA
    for file in readdir(benchmarks_dir)
        if endswith(file, "_$(sha).bson")
            return joinpath(benchmarks_dir, file)
        end
    end
    
    return nothing
end

# Run benchmarks for different problem sizes
function benchmark_comparison(n_values, existing_results=nothing, existing_n_values=Int[])
    # Initialize results structure
    if existing_results === nothing
        results = Dict(
            "n_values" => Int[],
            "numerics" => [],
            "py_numerics" => []
        )
    else
        results = existing_results
    end
    
    # Determine which n values need to be benchmarked
    new_n_values = setdiff(n_values, existing_n_values)
    
    if isempty(new_n_values)
        println("All requested n values already benchmarked.")
        return results
    end
    
    println("Running benchmarks for new n values: $new_n_values")
    
    for n in new_n_values
        println("\nBenchmarking n = $n")
        
        # Benchmark Julia implementation
        print("  Julia numerics... ")
        jul_bench = @benchmark numerics($n) samples=50 seconds=60
        times_ms = jul_bench.times ./ 1e6  # Convert to ms, keep all samples
        println("$(minimum(jul_bench.times) / 1e6) ms (min of $(length(jul_bench.times)) samples)")
        
        # Benchmark Python implementation
        print("  Python py_numerics... ")
        py_bench = @benchmark py_numerics($n) samples=50 seconds=60
        py_times_ms = py_bench.times ./ 1e6  # Convert to ms, keep all samples
        println("$(minimum(py_bench.times) / 1e6) ms (min of $(length(py_bench.times)) samples)")
        
        # Append to results
        push!(results["n_values"], n)
        push!(results["numerics"], times_ms)
        push!(results["py_numerics"], py_times_ms)
    end
    
    return results
end

# Create box plot comparing the implementations
function plot_benchmark_results(n_values, results)
    fig = Figure(size=(1200, 700))
    ax = Axis(fig[1, 1],
        xlabel="Problem Size (n)",
        ylabel="Time (ms)",
        title="Performance Distribution: Julia vs Python Implementation"
    )
    
    # Prepare data for box plots
    n_problems = length(n_values)
    positions = Float64[]
    times = Float64[]
    groups = String[]
    
    width = 0.35
    
    for (i, n) in enumerate(n_values)
        # Julia data
        for t in results["numerics"][i]
            push!(positions, i - width/2)
            push!(times, t)
            push!(groups, "Julia")
        end
        
        # Python data
        for t in results["py_numerics"][i]
            push!(positions, i + width/2)
            push!(times, t)
            push!(groups, "Python")
        end
    end
    
    # Create box plots
    julia_color = :steelblue
    python_color = :coral
    
    for (i, n) in enumerate(n_values)
        # Julia box plot
        boxplot!(ax, fill(i - width/2, length(results["numerics"][i])), 
                results["numerics"][i],
                width=width * 0.8,
                color=(julia_color, 0.5),
                strokecolor=julia_color,
                strokewidth=2,
                show_notch=false,
                label=(i == 1 ? "Julia numerics" : nothing))
        
        # Python box plot
        boxplot!(ax, fill(i + width/2, length(results["py_numerics"][i])), 
                results["py_numerics"][i],
                width=width * 0.8,
                color=(python_color, 0.5),
                strokecolor=python_color,
                strokewidth=2,
                show_notch=false,
                label=(i == 1 ? "Python py_numerics" : nothing))
    end
    
    # Set x-axis labels to show n values
    ax.xticks = (collect(1:length(n_values)), string.(n_values))
    
    # Add legend
    axislegend(ax, position=:lt)
    
    # Add speedup annotations (using median times)
    for (i, n) in enumerate(n_values)
        median_jul = median(results["numerics"][i])
        median_py = median(results["py_numerics"][i])
        speedup = median_py / median_jul
        max_val = max(maximum(results["numerics"][i]), maximum(results["py_numerics"][i]))
        text!(ax, i, max_val * 1.3,
            text=string(round(speedup, digits=2), "x"),
            align=(:center, :bottom),
            fontsize=12,
            color=:black)
    end
    
    return fig
end

# Run the benchmarks and create the plot
function main()
    n_values = [6, 8, 10, 12]
    
    # Check if benchmarks already exist for this SHA
    existing_file = find_benchmark_by_sha()
    existing_results = nothing
    existing_n_values = Int[]
    old_file = nothing
    
    if existing_file !== nothing && isfile(existing_file)
        println("Found existing benchmark file: $existing_file")
        existing_data = BSON.load(existing_file)
        existing_results = existing_data[:results]
        existing_n_values = existing_results["n_values"]
        println("Existing n values: $existing_n_values")
        old_file = existing_file
    else
        println("No existing benchmarks found for current git SHA.")
    end
    
    # Run benchmarks (only for new n values)
    results = benchmark_comparison(n_values, existing_results, existing_n_values)
    
    # Sort results by n_values
    sorted_indices = sortperm(results["n_values"])
    results["n_values"] = results["n_values"][sorted_indices]
    results["numerics"] = results["numerics"][sorted_indices]
    results["py_numerics"] = results["py_numerics"][sorted_indices]
    
    # Get new filename and save
    new_filename = get_benchmark_filename()
    
    # Delete old file if it exists and is different from new file
    if old_file !== nothing && old_file != new_filename && isfile(old_file)
        rm(old_file)
        println("Deleted old benchmark file: $old_file")
    end
    
    # Save results to BSON file
    BSON.@save new_filename results
    println("Results saved to $new_filename")
    
    # Print summary with statistics
    println("\n" * "="^60)
    println("BENCHMARK SUMMARY")
    println("="^60)
    for (i, n) in enumerate(results["n_values"])
        jul_times = results["numerics"][i]
        py_times = results["py_numerics"][i]
        
        jul_median = median(jul_times)
        py_median = median(py_times)
        speedup = py_median / jul_median
        
        println("n = $n:")
        println("  Julia:  median=$(round(jul_median, digits=3)) ms, " *
                "min=$(round(minimum(jul_times), digits=3)) ms, " *
                "max=$(round(maximum(jul_times), digits=3)) ms")
        println("  Python: median=$(round(py_median, digits=3)) ms, " *
                "min=$(round(minimum(py_times), digits=3)) ms, " *
                "max=$(round(maximum(py_times), digits=3)) ms")
        println("  Speedup (median): $(round(speedup, digits=2))x")
        println()
    end
    
    # Create and save plot
    fig = plot_benchmark_results(results["n_values"], results)
    save("benchmark_comparison.png", fig)
    println("Plot saved to benchmark_comparison.png")
    
    return fig
end

# Run if executed as main script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end