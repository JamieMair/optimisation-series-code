"""
Load benchmark results and plot execution time and memory usage vs n.

- Top axes: timing (filled band min–q75, median line, fitted curve)
- Bottom axes: peak memory mean per n
- Dashed reference lines on each axes (only plotted if within the y-range)

Usage:
    python plot_benchmarks.py
    python plot_benchmarks.py --input benchmarks/python_numerics.json
    python plot_benchmarks.py --input-mem benchmarks/python_numerics_memory.json
    python plot_benchmarks.py --n-extend 24
"""

import json
import argparse
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker
from scipy.optimize import minimize

INPUT = "benchmarks/python_numerics.json"
INPUT_MEM = "benchmarks/python_numerics_memory.json"

# 1 byte = 1, values in bytes
MEMORY_THRESHOLDS = [
    (1 * 1024**3, "Rasberry Pi (1 GB)"),
    (8 * 1024**3, "Uni desktop (8 GB)"),
    (256 * 1024**3, "Orpheus node (256 GB)"),
    (1536 * 1024**3, "High-mem node (1.5 TB)"),
    (1.2 * 10**15, "Isambard-AI (1.2 PB)"),
]

TIME_THRESHOLDS = [
    (60, "1 minute"),
    (3600, "1 hour"),
    (86400, "1 day"),
    (365 * 86400, "1 year"),
]


def model(n, a, b, c):
    """t(n) = 2^(a*n + b) + c"""
    return np.exp2(a * n + b) + c


def fit_model(ns, values):
    # Minimise MSE in log-space so every point contributes equally regardless
    # of magnitude (equivalent to minimising relative error).
    log_values = np.log(values)

    def loss(params):
        a, b, c = params
        t_pred = np.maximum(np.exp2(a * ns + b) + c, 1e-300)
        return np.mean((np.log(t_pred) - log_values) ** 2)

    n_mid = ns[len(ns) // 2]
    b0 = np.log2(max(values[len(ns) // 2], 1e-9)) - 0.7 * n_mid
    result = minimize(
        loss,
        x0=[0.7, b0, 0.0],
        method="Nelder-Mead",
        options={"maxiter": 50_000, "xatol": 1e-9, "fatol": 1e-12},
    )
    if not result.success:
        print(f"Warning: optimiser did not fully converge ({result.message})")
    return result.x


def add_threshold_lines(ax, thresholds, x_label):
    """Draw horizontal dashed lines only if they fall within the current y-axis range."""
    y_min, y_max = ax.get_ylim()
    for val, label in thresholds:
        if y_min <= val <= y_max:
            ax.axhline(val, color="grey", linewidth=0.9, linestyle="--", zorder=1)
            ax.text(
                x_label,
                val * 1.15,
                label,
                fontsize=9,
                color="grey",
                va="bottom",
                ha="left",
            )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=INPUT)
    parser.add_argument("--input-mem", default=INPUT_MEM)
    parser.add_argument(
        "--n-extend",
        type=int,
        default=None,
        help="Extend the fitted curve up to this value of n (e.g. 24)",
    )
    parser.add_argument(
        "--output", default=None, help="Save figure to file instead of showing"
    )
    args = parser.parse_args()

    # --- load timing data ---
    with open(args.input) as f:
        timing_data = json.load(f)

    ns = np.array([d["n"] for d in timing_data])
    mins = np.array([d["min"] for d in timing_data])
    medians = np.array([d["median"] for d in timing_data])
    q75s = np.array([d["q75"] for d in timing_data])

    # --- load memory data ---
    try:
        with open(args.input_mem) as f:
            mem_data = json.load(f)
        ns_mem = np.array([d["n"] for d in mem_data])
        mean_kb = np.array([d["mean_kb"] for d in mem_data])
        mean_bytes = mean_kb * 1024
        has_memory = True
    except FileNotFoundError:
        print(f"Memory file not found ({args.input_mem}), skipping memory plot.")
        has_memory = False

    # --- fit timing ---
    popt = fit_model(ns, medians)
    a, b, c = popt
    print(f"Timing fit:  a={a:.4f}  b={b:.4f}  c={c:.6f}")
    print(f"  t(n) = 2^({a:.4f}·n + {b:.4f}) + {c:.6f}")

    n_fit_max = args.n_extend if args.n_extend else ns[-1]
    ns_fit = np.linspace(ns[0], n_fit_max, 500)
    t_fit = model(ns_fit, *popt)

    # --- fit memory ---
    if has_memory:
        popt_mem = fit_model(ns_mem, mean_bytes)
        am, bm, cm = popt_mem
        print(f"Memory fit:  a={am:.4f}  b={bm:.4f}  c={cm:.2f}")
        ns_fit_mem = np.linspace(ns_mem[0], n_fit_max, 500)
        mem_fit = model(ns_fit_mem, *popt_mem)

    # --- x-ticks ---
    if args.n_extend and args.n_extend > ns[-1]:
        extended_ticks = list(range(ns[-1] + 2, args.n_extend + 1, 2))
        all_xticks = np.concatenate([ns, extended_ticks])
    else:
        all_xticks = ns

    # --- layout ---
    n_axes = 2 if has_memory else 1
    fig, axes = plt.subplots(n_axes, 1, figsize=(9, 5 * n_axes), sharex=True)
    if n_axes == 1:
        axes = [axes]
    ax_time, *rest = axes
    ax_mem = rest[0] if rest else None

    # ── timing axes ──────────────────────────────────────────────────────────
    ax_time.fill_between(
        ns,
        mins,
        q75s,
        alpha=0.35,
        color="steelblue",
        label="Min – 75th percentile",
        step="mid",
    )
    ax_time.plot(
        ns, medians, "o-", color="steelblue", linewidth=2, markersize=5, label="Median"
    )

    label_fit = (
        rf"Fit: $2^{{{a:.3f}n {b:+.3f}}} {c:+.4f}$"
        if abs(c) > 1e-6
        else rf"Fit: $2^{{{a:.3f}n {b:+.3f}}}$"
    )
    ax_time.plot(ns_fit, t_fit, "--", color="crimson", linewidth=1.8, label=label_fit)

    ax_time.set_ylabel("Time (s)", fontsize=13)
    ax_time.set_yscale("log")
    ax_time.legend(fontsize=11, loc="lower right")
    ax_time.grid(True, which="both", linestyle=":", alpha=0.5)

    # threshold lines — drawn after autoscale so ylim is set
    ax_time.autoscale(enable=True, axis="y")
    add_threshold_lines(ax_time, TIME_THRESHOLDS, ns_fit[0])

    # ── memory axes ──────────────────────────────────────────────────────────
    if ax_mem is not None:
        ax_mem.plot(
            ns_mem,
            mean_bytes,
            "s-",
            color="darkorange",
            linewidth=2,
            markersize=5,
            label="Mean peak memory",
        )

        label_fit_mem = (
            rf"Fit: $2^{{{am:.3f}n {bm:+.3f}}} {cm:+.0f}$"
            if abs(cm) > 1
            else rf"Fit: $2^{{{am:.3f}n {bm:+.3f}}}$"
        )
        ax_mem.plot(
            ns_fit_mem,
            mem_fit,
            "--",
            color="crimson",
            linewidth=1.8,
            label=label_fit_mem,
        )

        ax_mem.set_ylabel("Peak memory (bytes)", fontsize=13)
        ax_mem.set_yscale("log")
        ax_mem.legend(fontsize=11, loc="lower right")
        ax_mem.grid(True, which="both", linestyle=":", alpha=0.5)

        ax_mem.yaxis.set_major_formatter(
            matplotlib.ticker.LogFormatterSciNotation(base=10)
        )

        ax_mem.autoscale(enable=True, axis="y")
        add_threshold_lines(ax_mem, MEMORY_THRESHOLDS, ns_fit_mem[0])

        ax_mem.set_xlabel("$n$", fontsize=13)
    else:
        ax_time.set_xlabel("$n$", fontsize=13)

    # shared x-ticks (set on bottom axes via sharex)
    axes[-1].set_xticks(all_xticks)

    fig.tight_layout()

    if args.output:
        fig.savefig(args.output, dpi=150)
        print(f"Figure saved to {args.output}")
    else:
        plt.show()


if __name__ == "__main__":
    main()
