using PyCall


function load_python()
    pushfirst!(pyimport("sys")."path", "")
    py"""

    from original import *
    """

    py_numerics = py"numerics"
    py_analytics = py"analytics"

    return py_numerics, py_analytics
end
