using BSON
using CairoMakie
using Statistics
using PrettyTables
using Dates

# Get current git SHA
function get_git_sha()
    try
        sha = strip(read(`git rev-parse --short HEAD`, String))
        return sha
    catch
        return "unknown"
    end
end

# Get figure filename based on date and git SHA
function get_figure_filename(subfolder)
    date_str = Dates.format(Dates.today(), "yyyy-mm-dd")
    sha = get_git_sha()
    figures_dir = joinpath("figures", subfolder)
    
    # Create figures directory structure if it doesn't exist
    if !isdir(figures_dir)
        mkpath(figures_dir)
    end
    
    return joinpath(figures_dir, "$(date_str)_$(sha).png")
end

# Load benchmark data from current git SHA
function load_benchmark_data()
    sha = get_git_sha()
    benchmarks_dir = "benchmarks"
    
    # Find file with current SHA
    for file in readdir(benchmarks_dir)
        if endswith(file, "_$(sha).bson")
            filepath = joinpath(benchmarks_dir, file)
            println("Loading benchmark data from: $filepath")
            data = BSON.load(filepath)
            return data[:results]
        end
    end
    
    error("No benchmark file found for current git SHA: $sha")
end

# Extract minimum times for each n value
function extract_min_times(results)
    n_values = results["n_values"]
    julia_min_times = [minimum(times) for times in results["numerics"]]
    python_min_times = [minimum(times) for times in results["py_numerics"]]
    
    return n_values, julia_min_times, python_min_times
end

# Least squares linear fit: y = a + b*x
function linear_fit(x, y)
    n = length(x)
    @assert n == length(y) "x and y must have same length"
    
    # Calculate means
    x_mean = sum(x) / n
    y_mean = sum(y) / n
    
    # Calculate slope (b) and intercept (a)
    numerator = sum((x[i] - x_mean) * (y[i] - y_mean) for i in 1:n)
    denominator = sum((x[i] - x_mean)^2 for i in 1:n)
    
    b = numerator / denominator
    a = y_mean - b * x_mean
    
    return a, b
end

# Calculate R-squared
function r_squared(x, y, a, b)
    y_pred = [a + b * x[i] for i in 1:length(x)]
    ss_res = sum((y[i] - y_pred[i])^2 for i in 1:length(y))
    y_mean = sum(y) / length(y)
    ss_tot = sum((y[i] - y_mean)^2 for i in 1:length(y))
    return 1 - ss_res / ss_tot
end

# Fit log(time) vs n and extrapolate
function fit_and_extrapolate(n_values, times_ms, label)
    # Convert to log scale for times
    log_times = log.(times_ms)
    n_float = Float64.(n_values)
    
    # Fit: log(time) = a + b*n
    a, b = linear_fit(n_float, log_times)
    r2 = r_squared(n_float, log_times, a, b)
    
    return a, b, r2, label
end

# Print fit results in a pretty table
function print_fit_results(fits)
    println()
    
    # Create table data
    table_data = Matrix{Any}(undef, length(fits), 5)
    
    for (i, (a, b, r2, label)) in enumerate(fits)
        table_data[i, 1] = label
        table_data[i, 2] = string(round(exp(a), sigdigits=4))
        table_data[i, 3] = string(round(b, sigdigits=6))
        table_data[i, 4] = string(round(r2, sigdigits=6))
        table_data[i, 5] = "time ≈ $(round(exp(a), sigdigits=3)) × exp($(round(b, sigdigits=4)) × n) ms"
    end
    
    pretty_table(
        table_data;
        title = "Exponential Fit Results: log(time) = a + b×n",
        column_labels = [["Language", "exp(a)", "b", "R²", "Fitted Model"]],
        alignment = [:l, :r, :r, :r, :l],
        display_size = (-1, -1)
    )
end

# Extrapolate to larger n values
function extrapolate_times(a, b, n_extrapolate)
    return [exp(a + b * n) for n in n_extrapolate]
end

# Create visualization
function plot_extrapolation(n_values, julia_times, python_times, 
                           julia_fit, python_fit, n_extrapolate)
    fig = Figure(size=(1400, 600))
    
    # Left plot: Log scale
    ax1 = Axis(fig[1, 1],
        xlabel="Problem Size (n)",
        ylabel="Time (ms)",
        yscale=log10,
        title="Runtime Scaling (Log Scale)"
    )
    
    # Right plot: Linear scale for small n
    ax2 = Axis(fig[1, 2],
        xlabel="Problem Size (n)",
        ylabel="Time (ms)",
        title="Runtime Scaling (Linear Scale)"
    )
    
    # Unpack fit parameters
    julia_a, julia_b, julia_r2 = julia_fit
    python_a, python_b, python_r2 = python_fit
    
    # Calculate fitted lines
    julia_fit_times = extrapolate_times(julia_a, julia_b, n_values)
    python_fit_times = extrapolate_times(python_a, python_b, n_values)
    
    # Calculate extrapolated values
    julia_extrap = extrapolate_times(julia_a, julia_b, n_extrapolate)
    python_extrap = extrapolate_times(python_a, python_b, n_extrapolate)
    
    # Plot actual data points
    scatter!(ax1, n_values, julia_times, color=:steelblue, markersize=12, 
             label="Julia (actual)")
    scatter!(ax1, n_values, python_times, color=:coral, markersize=12,
             label="Python (actual)")
    
    scatter!(ax2, n_values, julia_times, color=:steelblue, markersize=12,
             label="Julia (actual)")
    scatter!(ax2, n_values, python_times, color=:coral, markersize=12,
             label="Python (actual)")
    
    # Plot fitted lines (on measured range)
    lines!(ax1, n_values, julia_fit_times, color=:steelblue, linewidth=2, 
           linestyle=:dash, label="Julia fit (R²=$(round(julia_r2, digits=4)))")
    lines!(ax1, n_values, python_fit_times, color=:coral, linewidth=2,
           linestyle=:dash, label="Python fit (R²=$(round(python_r2, digits=4)))")
    
    lines!(ax2, n_values, julia_fit_times, color=:steelblue, linewidth=2,
           linestyle=:dash)
    lines!(ax2, n_values, python_fit_times, color=:coral, linewidth=2,
           linestyle=:dash)
    
    # Plot extrapolated lines
    lines!(ax1, n_extrapolate, julia_extrap, color=(:steelblue, 0.5), 
           linewidth=2, linestyle=:dot, label="Julia (extrapolated)")
    lines!(ax1, n_extrapolate, python_extrap, color=(:coral, 0.5),
           linewidth=2, linestyle=:dot, label="Python (extrapolated)")
    
    lines!(ax2, n_extrapolate, julia_extrap, color=(:steelblue, 0.5),
           linewidth=2, linestyle=:dot)
    lines!(ax2, n_extrapolate, python_extrap, color=(:coral, 0.5),
           linewidth=2, linestyle=:dot)
    
    # Add legends
    axislegend(ax1, position=:lt)
    axislegend(ax2, position=:lt)
    
    return fig
end

# Format time in human-friendly units
function format_time(time_ms)
    if time_ms < 1000
        return string(round(time_ms, digits=2), " ms")
    elseif time_ms < 60_000  # < 60 seconds
        return string(round(time_ms / 1000, digits=2), " sec")
    elseif time_ms < 6_000_000  # < 100 minutes
        return string(round(time_ms / 60_000, digits=2), " min")
    elseif time_ms < 86_400_000  # < 24 hours (in ms)
        return string(round(time_ms / 3_600_000, digits=2), " hr")
    elseif time_ms < 31_536_000_000  # < 365 days (in ms)
        return string(round(time_ms / 86_400_000, digits=2), " days")
    else
        return string(round(time_ms / 31_536_000_000, digits=2), " yr")
    end
end

# Print extrapolated times in a table
function print_extrapolation_table(n_extrapolate, julia_extrap, python_extrap)
    # Prepare data for the table
    table_data = Matrix{Any}(undef, length(n_extrapolate), 4)
    
    for (i, n) in enumerate(n_extrapolate)
        julia_time = julia_extrap[i]
        python_time = python_extrap[i]
        speedup = python_time / julia_time
        
        table_data[i, 1] = n
        table_data[i, 2] = format_time(julia_time)
        table_data[i, 3] = format_time(python_time)
        table_data[i, 4] = string(round(speedup, digits=2), "x")
    end
    
    # Print using PrettyTables
    println()
    pretty_table(
        table_data;
        title = "Extrapolated Runtimes",
        column_labels = [["n", "Julia", "Python", "Speedup"]],
        alignment = [:r, :r, :r, :r],
        display_size = (-1, -1)
    )
end

# Main function
function main()
    # Load benchmark data
    results = load_benchmark_data()
    
    # Extract minimum times
    n_values, julia_times, python_times = extract_min_times(results)
    
    println("Loaded data for n = $n_values")
    println("Julia min times (ms): $julia_times")
    println("Python min times (ms): $python_times")
    
    # Fit exponential models: time = exp(a + b*n)
    julia_fit = fit_and_extrapolate(n_values, julia_times, "Julia")
    python_fit = fit_and_extrapolate(n_values, python_times, "Python")
    
    # Print fit results
    print_fit_results([julia_fit, python_fit])
    
    # Define extrapolation range
    n_min = minimum(n_values)
    n_max = 50
    n_extrapolate = collect(n_min:2:n_max)
    
    # Calculate extrapolated values
    julia_extrap = extrapolate_times(julia_fit[1], julia_fit[2], n_extrapolate)
    python_extrap = extrapolate_times(python_fit[1], python_fit[2], n_extrapolate)
    
    # Print table
    print_extrapolation_table(n_extrapolate, julia_extrap, python_extrap)
    
    # Create and save plot
    fig = plot_extrapolation(n_values, julia_times, python_times,
                            julia_fit, python_fit, n_extrapolate)
    figure_path = get_figure_filename("extrapolation")
    save(figure_path, fig)
    println("\nPlot saved to $figure_path")
    
    return fig
end

# Run if executed as main script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
