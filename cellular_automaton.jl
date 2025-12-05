import Base.Iterators: product
using PyCall
using Test
include("original_python.jl")

# Update odd sites (i % 2 == 1)
update_odd(u, n) = Tuple(i % 2 == 1 && (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0 ? !u[i] : u[i] for i in 1:n)
# Update even sites (i % 2 == 0)
update_even(u, n) = Tuple(i % 2 == 0 && (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0 ? !u[i] : u[i] for i in 1:n)
function numerics(n)
    s = [Dict{Int, Int}() for _ in 0:(Int(n ÷ 2)),  _ in 0:(Int(n ÷ 2))]  # list to store data
    c = Set([NTuple{n, Bool}((i...,)) for i in product(((0, 1) for _ in 1:n)...)])  # set of all configurations
    
    while length(c) > 0
        q = [0, 0]  # initial number of conserved quantities
        d = first(c)
        b = (d..., d[1:3]...)  # temporarily extend configuration; due to periodicity
        for i in 1:n  # update number of conserved quantities
            if b[i : i + 2] == (0, 1, 0)
                q[i % 2 + 1] += 1
                q[2 - i % 2] += 1
            end
            if b[i : i + 2] == (0, 1, 1)
                q[i % 2 + 1] += 1
            end
            if b[i : i + 2] == (1, 1, 1)
                q[i % 2 + 1] += 1
            end
        end
        
        orbit_length = 1
        u = d
        
        while true # generate orbit
            delete!(c, u)
            u = update_odd(u, n)
            u = update_even(u, n)
            if u == d # found initial state
                break
            end
            orbit_length += 1
        end
        l = orbit_length # length of orbit

        correct_dict = s[q[1]+1,q[2]+1]
        if haskey(correct_dict, l)  # update list to store new data
            correct_dict[l] += l
        else
            correct_dict[l] = l
        end
    end
    return s
end

const py_numerics, py_analytics = load_python()

function check_agrees(n)
    py_result = py_numerics(n)
    jul_result = numerics(n)

    for (a, b) in zip(py_result, jul_result)
        for (bkey, bval) in b 
            @assert haskey(a, bkey)
            @assert a[bkey] == bval
        end
    end

    println("[Test Passed]")
end