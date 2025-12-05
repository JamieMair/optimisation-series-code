using Dates

"""
    get_git_sha()

Get the current git commit SHA (short version).
Returns "unknown" if not in a git repository.
"""
function get_git_sha()
    try
        sha = strip(read(`git rev-parse --short HEAD`, String))
        return sha
    catch
        return "unknown"
    end
end

"""
    get_figure_filename(subfolder)

Generate a figure filename based on current date and git SHA.
Creates the directory structure if it doesn't exist.

# Arguments
- `subfolder`: Subdirectory within figures/ to save the file

# Returns
- String path to the figure file
"""
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

"""
    get_benchmark_filename()

Generate a benchmark filename based on current date and git SHA.
Creates the benchmarks directory if it doesn't exist.

# Returns
- String path to the benchmark file
"""
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

"""
    find_benchmark_by_sha()

Find an existing benchmark file matching the current git SHA.

# Returns
- String path to the benchmark file if found, nothing otherwise
"""
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

"""
    format_time(time_ms)

Format time in milliseconds to human-friendly units (ms, sec, min, hr, days, yr).

# Arguments
- `time_ms`: Time in milliseconds

# Returns
- String representation with appropriate units
"""
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
