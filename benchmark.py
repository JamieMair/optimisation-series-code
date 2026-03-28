"""
Benchmark the numerics() function for n=2..18, running each point multiple
times and saving timing statistics to a JSON file.
"""

import json
import time
import tracemalloc
import statistics
import argparse
from original import numerics

N_MIN = 2
N_MAX = 20
N_RUNS = 30  # how many timed repetitions per n
OUTPUT = "benchmarks/python_numerics.json"
OUTPUT_MEM = "benchmarks/python_numerics_memory.json"


def benchmark_n(n, runs, do_timing=True, do_memory=True):
    times = []
    peak_bytes = []
    for _ in range(runs):
        if do_memory:
            tracemalloc.start()
        if do_timing:
            t0 = time.perf_counter()
        numerics(n)
        if do_timing:
            times.append(time.perf_counter() - t0)
        if do_memory:
            _, peak = tracemalloc.get_traced_memory()
            tracemalloc.stop()
            peak_bytes.append(peak)

    timing = None
    if do_timing:
        times.sort()
        q25 = statistics.quantiles(times, n=4)[0]
        q75 = statistics.quantiles(times, n=4)[2]
        timing = {
            "n": n,
            "times": times,
            "min": times[0],
            "max": times[-1],
            "median": statistics.median(times),
            "q25": q25,
            "q75": q75,
            "mean": statistics.mean(times),
            "stdev": statistics.stdev(times) if len(times) > 1 else 0.0,
        }

    memory = None
    if do_memory:
        memory = {
            "n": n,
            "peak_bytes": peak_bytes,
            "mean_kb": statistics.mean(peak_bytes) / 1024,
        }

    return timing, memory


def main():
    parser = argparse.ArgumentParser(description="Benchmark numerics(n)")
    parser.add_argument("--nmax", type=int, default=N_MAX)
    parser.add_argument("--nmin", type=int, default=N_MIN)
    parser.add_argument("--runs", type=int, default=N_RUNS)
    parser.add_argument("--output", default=OUTPUT)
    parser.add_argument("--output-mem", default=OUTPUT_MEM)
    parser.add_argument("--no-timing", action="store_true", help="Skip timing benchmarks")
    parser.add_argument("--no-memory", action="store_true", help="Skip memory benchmarks")
    args = parser.parse_args()

    do_timing = not args.no_timing
    do_memory = not args.no_memory

    if not do_timing and not do_memory:
        parser.error("--no-timing and --no-memory cannot both be set")

    timing_results = []
    memory_results = []
    nmin = args.nmin if args.nmin % 2 == 0 else args.nmin + 1
    for n in range(nmin, args.nmax + 1, 2):
        print(f"  n={n:2d}  ({args.runs} runs)...", end="", flush=True)
        timing, memory = benchmark_n(n, args.runs, do_timing=do_timing, do_memory=do_memory)
        suffix = ""
        if timing:
            timing_results.append(timing)
            suffix += f"  median={timing['median']:.4f}s  min={timing['min']:.4f}s  max={timing['max']:.4f}s"
        if memory:
            memory_results.append(memory)
            suffix += f"  mem={memory['mean_kb']:.1f} KB"
        print(suffix)

    if do_timing:
        with open(args.output, "w") as f:
            json.dump(timing_results, f, indent=2)
        print(f"\nTiming  saved to {args.output}")
    if do_memory:
        with open(args.output_mem, "w") as f:
            json.dump(memory_results, f, indent=2)
        print(f"Memory  saved to {args.output_mem}")


if __name__ == "__main__":
    main()
