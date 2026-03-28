"""
Load benchmark results and plot execution time vs n.

- Filled area: min to 75th percentile (worst 25%)
- Solid line: median
- Dashed line: fitted curve  t(n) = 2^(a*n + b) + c

Usage:
    python plot_benchmarks.py
    python plot_benchmarks.py --input benchmarks/python_numerics.json
    python plot_benchmarks.py --n-extend 24   # extend the fitted curve to n=24
"""

import json
import argparse
import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import minimize

INPUT = "benchmarks/python_numerics.json"


def model(n, a, b, c):
    """t(n) = 2^(a*n + b) + c"""
    return np.exp2(a * n + b) + c


def fit_model(ns, medians):
    # Minimise MSE in log-space so every point contributes equally regardless
    # of magnitude (equivalent to minimising relative error).
    log_medians = np.log(medians)

    def loss(params):
        a, b, c = params
        t_pred = np.maximum(np.exp2(a * ns + b) + c, 1e-300)
        return np.mean((np.log(t_pred) - log_medians) ** 2)

    n_mid = ns[len(ns) // 2]
    b0 = np.log2(max(medians[len(ns) // 2], 1e-9)) - 0.7 * n_mid
    result = minimize(
        loss,
        x0=[0.7, b0, 0.0],
        method="Nelder-Mead",
        options={"maxiter": 50_000, "xatol": 1e-9, "fatol": 1e-12},
    )
    if not result.success:
        print(f"Warning: optimiser did not fully converge ({result.message})")
    return result.x


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default=INPUT)
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

    with open(args.input) as f:
        data = json.load(f)

    ns = np.array([d["n"] for d in data])
    mins = np.array([d["min"] for d in data])
    medians = np.array([d["median"] for d in data])
    q75s = np.array([d["q75"] for d in data])

    # --- fit ---
    popt = fit_model(ns, medians)
    a, b, c = popt
    print(f"Fitted parameters:  a={a:.4f}  b={b:.4f}  c={c:.6f}")
    print(f"  t(n) = 2^({a:.4f}·n + {b:.4f}) + {c:.6f}")

    n_fit_max = args.n_extend if args.n_extend else ns[-1]
    ns_fit = np.linspace(ns[0], n_fit_max, 500)
    t_fit = model(ns_fit, *popt)

    # --- plot ---
    fig, ax = plt.subplots(figsize=(9, 5))

    # filled band: min → q75
    ax.fill_between(
        ns,
        mins,
        q75s,
        alpha=0.35,
        color="steelblue",
        label="Min – 75th percentile",
        step="mid",
    )

    # median
    ax.plot(
        ns, medians, "o-", color="steelblue", linewidth=2, markersize=5, label="Median"
    )

    # fitted curve
    label_fit = (
        rf"Fit: $2^{{{a:.3f}n {b:+.3f}}} {c:+.4f}$"
        if abs(c) > 1e-6
        else rf"Fit: $2^{{{a:.3f}n {b:+.3f}}}$"
    )
    ax.plot(ns_fit, t_fit, "--", color="crimson", linewidth=1.8, label=label_fit)

    ax.set_xlabel("$n$", fontsize=13)
    ax.set_ylabel("Time (s)", fontsize=13)
    # ax.set_title("Python numerics() benchmark", fontsize=14)
    ax.set_yscale("log")

    # x-ticks: include all data points plus any extended range ticks
    if args.n_extend and args.n_extend > ns[-1]:
        extended_ticks = list(range(ns[-1] + 2, args.n_extend + 1, 2))
        all_xticks = np.concatenate([ns, extended_ticks])
    else:
        all_xticks = ns
    ax.set_xticks(all_xticks)

    # horizontal threshold lines: 1 hour, 1 day, 1 year
    thresholds = [
        (60,            "1 minute"),
        (3600,          "1 hour"),
        (86400,         "1 day"),
        (365 * 86400,   "1 year"),
    ]
    x_label = ns_fit[0]  # near n=0 (left edge of fit range)
    for t_val, t_label in thresholds:
        ax.axhline(t_val, color="grey", linewidth=0.9, linestyle="--", zorder=1)
        # place text just above the dashed line, near the left edge
        ax.text(
            x_label,
            t_val * 1.15,
            t_label,
            fontsize=9,
            color="grey",
            va="bottom",
            ha="left",
        )

    ax.legend(fontsize=11, loc="lower right")
    ax.grid(True, which="both", linestyle=":", alpha=0.5)
    fig.tight_layout()

    if args.output:
        fig.savefig(args.output, dpi=150)
        print(f"Figure saved to {args.output}")
    else:
        plt.show()


if __name__ == "__main__":
    main()
