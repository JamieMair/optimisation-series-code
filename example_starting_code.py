from itertools import product
from collections import defaultdict


def step(config, rule):
    n = len(config)
    next_config = []
    for i, c in enumerate(config):
        l = config[i - 1] if i > 0 else config[-1]
        r = config[i + 1] if (i + 1) < n else config[0]

        rule_index = 4 * l + 2 * c + r
        output = (rule // 2 ** (rule_index)) % 2
        next_config.append(output)
    return tuple(next_config)


def find_orbits(n, rule):
    configurations = set([i for i in product([0, 1], repeat=n)])
    orbital_freqs = defaultdict(int)
    while len(configurations) > 0:
        starting_state = next(iter(configurations))
        path = [starting_state]
        state = starting_state
        while True:
            state = step(state, rule)
            if state in path:
                break

            path.append(state)
        orbit_length = len(path) - path.index(state)
        orbital_freqs[orbit_length] += len(path)

        configurations -= set(path)
    return orbital_freqs
