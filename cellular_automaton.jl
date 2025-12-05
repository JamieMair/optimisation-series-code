import Base.Iterators: product
using PyCall
using Test
include("original_python.jl")

# Update odd sites (i % 2 == 1)
update_odd(u, n) = Tuple(i % 2 == 1 && (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0 ? !u[i] : u[i] for i in 1:n)
# Update even sites (i % 2 == 0)
update_even(u, n) = Tuple(i % 2 == 0 && (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0 ? !u[i] : u[i] for i in 1:n)

should_flip(u, i, n) = (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0

function update_even!(u′, u)
    n = length(u)
    for i in 1:n # only odd sites
        if i % 2 == 1 && should_flip(u, i, n)
            u′[i] = !u[i]
        else
            u′[i] = u[i]
        end
    end
    return u′
end
function update_odd!(u′, u)
    n = length(u)
    for i in 1:n # only odd sites
        if i % 2 == 0 && should_flip(u, i, n)
            u′[i] = !u[i]
        else
            u′[i] = u[i]
        end
    end
    return u′
end

function periodic_windows(u, i)
    n = length(u)
    return (u[mod1(i, n)], u[mod1(i + 1, n)], u[mod1(i + 2, n)])
end

function conserved_quantities(u)
    n = length(u)
    q = Int[0, 0]
    @views for i in 1:n  # update number of conserved quantities
        window = periodic_windows(u, i)
        if window == (0, 1, 0)
            q[i % 2 + 1] += 1
            q[2 - i % 2] += 1
        end
        if window == (0, 1, 1)
            q[i % 2 + 1] += 1
        end
        if window == (1, 1, 1)
            q[i % 2 + 1] += 1
        end
    end
    return q
end

function numerics(n)
    s = [Dict{Int, Int}() for _ in 0:(Int(n ÷ 2)),  _ in 0:(Int(n ÷ 2))]  # list to store data
    c = Set{BitVector}(BitVector((i...,)) for i in product(((0, 1) for _ in 1:n)...))  # set of all configurations
    

    u = BitVector(undef, n)
    u′ = similar(u)

    while length(c) > 0
        d = first(c)
        q = conserved_quantities(d)  # initial number of conserved quantities
        
        orbit_length = 1
        u .= d # set u to initial state
        
        while true # generate orbit
            delete!(c, u) # count configuration as visited
            update_odd!(u′, u)
            update_even!(u, u′)
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