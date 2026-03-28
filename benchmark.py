"""
Benchmark the numerics() function for n=2..18, running each point multiple
times and saving timing statistics to a JSON file.
"""

import json
import time
import statistics
import argparse
from original import numerics

N_MIN = 2
N_MAX = 20
N_RUNS = 30  # how many timed repetitions per n
OUTPUT = "benchmarks/python_numerics.json"


def benchmark_n(n, runs):
    times = []
    for _ in range(runs):
        t0 = time.perf_counter()
        numerics(n)
        times.append(time.perf_counter() - t0)
    times.sort()
    q25 = statistics.quantiles(times, n=4)[0]  # 25th percentile
    q75 = statistics.quantiles(times, n=4)[2]  # 75th percentile
    return {
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


def main():
    parser = argparse.ArgumentParser(description="Benchmark numerics(n)")
    parser.add_argument("--nmax", type=int, default=N_MAX)
    parser.add_argument("--nmin", type=int, default=N_MIN)
    parser.add_argument("--runs", type=int, default=N_RUNS)
    parser.add_argument("--output", default=OUTPUT)
    args = parser.parse_args()

    results = []
    nmin = args.nmin if args.nmin % 2 == 0 else args.nmin + 1
    for n in range(nmin, args.nmax + 1, 2):
        print(f"  n={n:2d}  ({args.runs} runs)...", end="", flush=True)
        entry = benchmark_n(n, args.runs)
        results.append(entry)
        print(
            f"  median={entry['median']:.4f}s  min={entry['min']:.4f}s  max={entry['max']:.4f}s"
        )

    with open(args.output, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to {args.output}")


if __name__ == "__main__":
    main()
