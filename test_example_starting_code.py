import pytest
from example_starting_code import step, find_orbits

# Rule 110 and Rule 90 are well-known; Rule 0 maps everything to 0, Rule 255 to 1.

RULE_0 = 0
RULE_255 = 255
RULE_90 = 90  # XOR rule: output = l XOR r


class TestStep:
    def test_returns_tuple(self):
        result = step((0, 0, 0), RULE_0)
        assert isinstance(result, tuple)

    def test_rule_0_all_zeros(self):
        assert step((0, 0, 0), RULE_0) == (0, 0, 0)
        assert step((1, 0, 1), RULE_0) == (0, 0, 0)
        assert step((1, 1, 1), RULE_0) == (0, 0, 0)

    def test_rule_255_all_ones(self):
        assert step((0, 0, 0), RULE_255) == (1, 1, 1)
        assert step((1, 0, 1), RULE_255) == (1, 1, 1)

    def test_wrapping_boundary(self):
        # Left cell of index 0 should wrap to config[-1]
        # Right cell of last index should wrap to config[0]
        config = (1, 0, 0)
        result = step(config, RULE_90)
        # Rule 90: out = l XOR r (ignores centre)
        # index 0: l=config[-1]=0, r=config[1]=0 → 0 XOR 0 = 0
        # index 1: l=config[0]=1, r=config[2]=0 → 1 XOR 0 = 1
        # index 2: l=config[1]=0, r=config[0]=1 → 0 XOR 1 = 1
        assert result == (0, 1, 1)

    def test_length_preserved(self):
        for n in [1, 3, 5, 8]:
            config = tuple([0] * n)
            assert len(step(config, RULE_0)) == n

    def test_single_cell(self):
        # Single cell wraps to itself on both sides: neighbourhood is (c, c, c)
        assert step((0,), RULE_0) == (0,)
        assert step((1,), RULE_255) == (1,)


class TestFindOrbits:
    def test_rule_0_single_fixed_point(self):
        # Rule 0 maps every config to all-zeros in one step;
        # all-zeros is a fixed point, so every orbit has length 1.
        orbits = find_orbits(3, RULE_0)
        assert set(orbits.keys()) == {1}

    def test_rule_255_fixed_point(self):
        # Rule 255 maps every config to all-ones; all-ones is a fixed point.
        orbits = find_orbits(3, RULE_255)
        assert set(orbits.keys()) == {1}

    def test_rule_0_orbit_count(self):
        # Rule 0: everything maps to all-zeros, which is a fixed point.
        # Every trajectory has orbit length 1.
        orbits = find_orbits(4, RULE_0)
        assert list(orbits.keys()) == [1]
        assert orbits[1] > 0

    def test_returns_dict(self):
        orbits = find_orbits(3, RULE_0)
        assert isinstance(orbits, dict)

    def test_orbit_lengths_positive(self):
        for rule in [0, 90, 110, 255]:
            orbits = find_orbits(4, rule)
            assert all(k > 0 for k in orbits.keys())
