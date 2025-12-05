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
function conserved_quantities!(q, u)
    n = length(u)
    fill!(q, 0)
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

function to_int(u)
    x = 0
    for i in 1:length(u)
        x += Int(u[i]) << (i-1)
    end
    x
end
function from_int(x, n)
    u = BitVector(undef, n)
    i = 1
    while x > 0
        x, u[i] = fldmod(x, 2)
        i += 1
    end
    u
end
function from_int!(u::BitVector, x)
    i = 1
    while x > 0
        x, u[i] = fldmod(x, 2)
        i += 1
    end
    u
end

function numerics(n)
    s = [Dict{Int, Int}() for _ in 0:(Int(n ÷ 2)),  _ in 0:(Int(n ÷ 2))]  # list to store data
    
    
    u = BitVector(undef, n)
    u′ = similar(u)

    has_visited = BitVector(undef, 2^n)
    fill!(has_visited, false)

    u = BitVector(undef, n)
    u′ = similar(u)
    q = [0, 0]
    for i in 0:(2^n-1)
        if has_visited[i+1]
            continue
        else
            has_visited[i+1] = true
        end

        from_int!(u, i)
        conserved_quantities!(q, u)

        orbit_length = 1
        while true
            update_odd!(u′, u)
            update_even!(u, u′)
            next_config = to_int(u)
            has_visited[next_config+1] = true
            if next_config == i
                break
            end
            orbit_length += 1
        end

        correct_dict = s[q[1]+1,q[2]+1]
        if haskey(correct_dict, orbit_length)  # update list to store new data
            correct_dict[orbit_length] += orbit_length
        else
            correct_dict[orbit_length] = orbit_length
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