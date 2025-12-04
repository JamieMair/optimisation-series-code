import Base.Iterators: product
# Update odd sites (i % 2 == 1)
update_odd(u, n) = Tuple(i % 2 == 1 && (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0 ? 1 - u[i] : u[i] for i in 1:n)
# Update even sites (i % 2 == 0)
update_even(u, n) = Tuple(i % 2 == 0 && (1 - (1 - u[mod1(i-1, n)]) * (1 - u[mod1(i+1, n)])) != 0 ? 1 - u[i] : u[i] for i in 1:n)
function numerics(n)
    s = [[Dict{Int, Int}() for _ in 0:(Int(n ÷ 2))] for _ in 0:(Int(n ÷ 2))]  # list to store data
    c = Set([i for i in product(((0, 1) for _ in 1:n)...)])  # set of all configurations
    m = length(c)  # initial number of configurations
    while m > 0
        q = [0, 0]  # initial number of conserved quantities
        d = first(c)
        b = (d..., d[1:3]...)  # temporarily extend configuration; due to periodicity
        for i in 1:n  # update number of conserved quantities
            if b[i : i + 3] == (0, 1, 0)
                q[i % 2] += 1
                q[1 - i % 2] += 1
            end
            if b[i : i + 3] == (0, 1, 1)
                q[i % 2] += 1
            end
            if b[i : i + 3] == (1, 1, 1)
                q[i % 2] += 1
            end
        end
        t = [d]  # initial configuration in orbit
        while true # generate orbit
            u = t[end]
            u = update_odd(u, n)
            u = update_even(u, n)
            if u == t[1]
                break
            end
            push!(t, u)
        end
        l = length(t)  # length of orbit
        if haskey(s[q[1]+1][q[2]+1], l)  # update list to store new data
            s[q[1]+1][q[2]+1][l] += l
        else
            s[q[1]+1][q[2]+1][l] = l
        end
        setdiff!(c, t)
        m = length(c)
    end
    return s
end