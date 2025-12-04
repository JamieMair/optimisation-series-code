# %% === imports ===

import time

import numpy as np
import sympy as sp
import pickle

from itertools import product

# %% === functions ===


def numerics(n):
    s = [
        [{} for i in range(int(n / 2) + 1)] for j in range(int(n / 2) + 1)
    ]  # list to store data
    c = set([i for i in product([0, 1], repeat=n)])  # set of all configurations
    m = len(c)  # initial number of configurations
    while m:
        q = [0, 0]  # initial number of conserved quantities
        for d in c:  # get any configuration from set
            break
        b = d + d[:3]  # temporarily extend configuration; due to periodicity
        for i in range(n):  # update number of conserved quantities
            if b[i : i + 3] == (0, 1, 0):
                q[i % 2] += 1
                q[1 - i % 2] += 1
            if b[i : i + 3] == (0, 1, 1):
                q[i % 2] += 1
            if b[i : i + 3] == (1, 1, 1):
                q[i % 2] += 1
        t = [d]  # initial configuration in orbit
        while True:  # generate orbit
            u = t[-1]
            u = tuple(
                [
                    (
                        1 - u[i]
                        if 1 - (1 - u[i - 1]) * (1 - u[(i + 1) % n]) and i % 2 == 1
                        else u[i]
                    )
                    for i in range(n)
                ]
            )
            u = tuple(
                [
                    (
                        1 - u[i]
                        if 1 - (1 - u[i - 1]) * (1 - u[(i + 1) % n]) and i % 2 == 0
                        else u[i]
                    )
                    for i in range(n)
                ]
            )
            if (
                u == t[0]
            ):  # check if final and initial configurations of orbit are equal
                break
            t.append(u)  # add updated configuration to orbit
        l = len(t)  # length of orbit
        if l in s[q[0]][q[1]]:  # update list to store new data
            s[q[0]][q[1]][l] += l
        else:
            s[q[0]][q[1]][l] = l
        c -= set(t)  # remove orbit from set of configurations
        m = len(c)  # update number of configurations
    return s


def analytics(n):
    s = [[{} for i in range(n + 1)] for j in range(n + 1)]
    for qp in range(n + 1):
        for qn in range(n + 1):
            m = round(n + qp + qn)
            mp = round(n - qp + qn)
            mn = round(n - qn + qp)
            if qp <= mp and qn <= mn:
                vp = 1 - 2 * qn / m
                vn = 1 - 2 * qp / m
                up = round(m / sp.igcd(m, round(m * vp)))
                un = round(m / sp.igcd(m, round(m * vn)))
                lp = round(n * up / sp.igcd(n * up, round(vp * up)))
                ln = round(n * un / sp.igcd(n * un, round(vn * un)))
                gp = sp.igcd(lp, mp, qp)
                gn = sp.igcd(ln, mn, qn)
                for dp in sp.divisors(gp):
                    for dn in sp.divisors(gn):
                        q = []
                        for ddp in sp.divisors(round(gp / dp)):
                            for ddn in sp.divisors(round(gn / dn)):
                                q.append(
                                    round(
                                        sp.mobius(ddp)
                                        * sp.mobius(ddn)
                                        * sp.binomial(
                                            round(mp / dp / ddp), round(qp / dp / ddp)
                                        )
                                        * sp.binomial(
                                            round(mn / dn / ddn), round(qn / dn / ddn)
                                        )
                                    )
                                )
                        q = int(round(n * m / mp / mn * sum(q)))
                        l = round(sp.ilcm(round(lp / dp), round(ln / dn)))
                        if q:
                            s[qp][qn].update(
                                {l: s[qp][qn][l] + q if l in s[qp][qn] else q}
                            )
    return s


def check_numerics(n):  # checks analytics matches numerics for m = 2*n
    r = []
    s = numerics(2 * n)
    print("Do analytics match numerics?", analytics(n) == s)
    for i, u in enumerate(s):
        for j, v in enumerate(u):
            if len(v):
                for l, k in v.items():
                    r.append((i, j, k, l))
    return r


def time_numerics(n):  # times numerics for m = 2, 4, ..., n
    for m in range(2, 2 * n + 1, 2):
        t = time.time()
        s = numerics(m)
        print("n =", m, ":    t =", round(time.time() - t, 0), "s\n")
    return


def save_pickle(file_path, obj):
    with open(file_path, "wb") as f:
        pickle.dump(obj, f)


def load_all_results(file_path):
    with open(file_path, "rb") as f:
        obj = pickle.load(f)
    return obj
