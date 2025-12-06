# Node struct for computation tree
# op: operation byte (0=xor, 1=or, 2=and, 3=not, 4=nor)
# left, right: indices where 0=left, 1=center, 2=right, 3+=node index in container
mutable struct Node
    op::UInt8
    left::UInt32
    right::UInt32
end

# Operation mapping
const OP_XOR = UInt8(0)
const OP_OR = UInt8(1)
const OP_AND = UInt8(2)
const OP_NOT = UInt8(3)
const OP_NOR = UInt8(4)

# Input mapping
const INPUT_LEFT = UInt32(0)
const INPUT_CENTER = UInt32(1)
const INPUT_RIGHT = UInt32(2)

# Map operation byte to function
@inline function apply_op(op::UInt8, left::Bool, right::Bool)
    if op == OP_XOR
        return xor(left, right)
    elseif op == OP_OR
        return left | right
    elseif op == OP_AND
        return left & right
    elseif op == OP_NOT
        return ~left
    elseif op == OP_NOR
        return ~(left | right)
    else
        error("Unknown operation: $op")
    end
end

function find_formula(x)
    @assert x < (1<<8)


end

function next_bit(left::Bool, center::Bool, right::Bool, rule)
    index = UInt8(left) << 2 + UInt8(center) << 1 + UInt8(right)
    result = (rule & (1 << index)) >> index
    return Bool(result)
end

# Evaluate a node tree
@inline function eval_node(node_idx::UInt32, nodes::Vector{Node}, left::Bool, center::Bool, right::Bool)
    if node_idx == INPUT_LEFT
        return left
    elseif node_idx == INPUT_CENTER
        return center
    elseif node_idx == INPUT_RIGHT
        return right
    else
        node = nodes[node_idx - 2]  # Offset by 3 reserved indices
        left_val = eval_node(node.left, nodes, left, center, right)
        right_val = eval_node(node.right, nodes, left, center, right)
        return apply_op(node.op, left_val, right_val)
    end
end

function test_candidate(nodes::Vector{Node}, root_idx::UInt32, rule)
    for left in (false, true), center in (false, true), right in (false, true)
        if eval_node(root_idx, nodes, left, center, right) != next_bit(left, center, right, rule)
            return false
        end
    end
    return true
end

function test_candidate(f, rule)
    for left in (false, true), center in (false, true), right in (false, true)
        if f(left, center, right) != next_bit(left, center, right, rule)
            return false
        end
    end
    return true
end

const _candidate_cache = Dict{Int, Tuple{Vector{Node}, Vector{UInt32}}}()

function generate_all_candidates(depth)
    if haskey(_candidate_cache, depth)
        return _candidate_cache[depth]
    end
    
    ops = (OP_XOR, OP_OR, OP_AND, OP_NOT, OP_NOR)
    bits = (INPUT_LEFT, INPUT_CENTER, INPUT_RIGHT)

    if depth == 0 # if no ops are allowed, return just the bits
        _candidate_cache[depth] = (Node[], collect(bits))
        return _candidate_cache[depth]
    end

    nodes = Node[]
    root_indices = UInt32[]
    
    # Get sub-candidates from previous depth
    sub_nodes, sub_roots = generate_all_candidates(depth - 1)
    
    # Offset for new nodes (account for reserved indices 0-2)
    base_offset = UInt32(length(sub_nodes) + 3)
    
    # Copy sub-nodes to our container
    append!(nodes, sub_nodes)
    
    for op in ops
        # Left from sub-candidates, right from sub-candidates
        for left_idx in sub_roots
            for right_idx in sub_roots
                node = Node(op, left_idx, right_idx)
                push!(nodes, node)
                push!(root_indices, base_offset + UInt32(length(root_indices)))
            end
            # Right from input bits
            for right_idx in bits
                node = Node(op, left_idx, right_idx)
                push!(nodes, node)
                push!(root_indices, base_offset + UInt32(length(root_indices)))
            end
        end
        
        # Left from input bits, right from sub-candidates
        for left_idx in bits
            for right_idx in sub_roots
                node = Node(op, left_idx, right_idx)
                push!(nodes, node)
                push!(root_indices, base_offset + UInt32(length(root_indices)))
            end
            # Right from input bits
            for right_idx in bits
                node = Node(op, left_idx, right_idx)
                push!(nodes, node)
                push!(root_indices, base_offset + UInt32(length(root_indices)))
            end
        end
    end
    
    _candidate_cache[depth] = (nodes, root_indices)
    return _candidate_cache[depth]
end

# Pretty print a node as a string expression
function pretty_print_node(node_idx::UInt32, nodes::Vector{Node})
    if node_idx == INPUT_LEFT
        return "l"
    elseif node_idx == INPUT_CENTER
        return "c"
    elseif node_idx == INPUT_RIGHT
        return "r"
    else
        node = nodes[node_idx - 2]  # Offset by 3 reserved indices
        left_str = pretty_print_node(node.left, nodes)
        right_str = pretty_print_node(node.right, nodes)
        
        if node.op == OP_XOR
            return "xor($left_str, $right_str)"
        elseif node.op == OP_OR
            return "($left_str | $right_str)"
        elseif node.op == OP_AND
            return "($left_str & $right_str)"
        elseif node.op == OP_NOT
            return "~($left_str)"
        elseif node.op == OP_NOR
            return "~($left_str | $right_str)"
        else
            error("Unknown operation: $(node.op)")
        end
    end
end

# Convert node to valid Julia code string (bitwise operators)
function node_to_julia_code(node_idx::UInt32, nodes::Vector{Node})
    if node_idx == INPUT_LEFT
        return "l"
    elseif node_idx == INPUT_CENTER
        return "c"
    elseif node_idx == INPUT_RIGHT
        return "r"
    else
        node = nodes[node_idx - 2]  # Offset by 3 reserved indices
        left_str = node_to_julia_code(node.left, nodes)
        right_str = node_to_julia_code(node.right, nodes)
        
        if node.op == OP_XOR
            return "xor($left_str, $right_str)"
        elseif node.op == OP_OR
            return "($left_str | $right_str)"
        elseif node.op == OP_AND
            return "($left_str & $right_str)"
        elseif node.op == OP_NOT
            return "~($left_str)"
        elseif node.op == OP_NOR
            return "~($left_str | $right_str)"
        else
            error("Unknown operation: $(node.op)")
        end
    end
end

# Find all candidates that satisfy each of the 256 rules
function find_candidates_for_all_rules(depth)
    nodes, root_indices = generate_all_candidates(depth)
    
    # Dictionary mapping rule number to list of candidate indices
    rule_to_candidates = Dict{UInt8, Vector{UInt32}}()
    
    # Initialise empty vectors for each rule
    for rule in UInt8(0):UInt8(255)
        rule_to_candidates[rule] = UInt32[]
    end
    
    # Test each candidate against all rules
    println("Testing $(length(root_indices)) candidates against 256 rules...")
    for (idx, root_idx) in enumerate(root_indices)
        if idx % 1000 == 0
            println("  Processed $idx/$(length(root_indices)) candidates")
        end
        for rule in UInt8(0):UInt8(255)
            if test_candidate(nodes, root_idx, rule)
                push!(rule_to_candidates[rule], root_idx)
            end
        end
    end
    
    return nodes, rule_to_candidates
end

# Convert rule_to_candidates dictionary to rule_to_julia_code dictionary
function get_julia_code_for_rules(nodes::Vector{Node}, rule_to_candidates::Dict{UInt8, Vector{UInt32}})
    rule_to_code = Dict{UInt8, Vector{String}}()
    
    for (rule, candidate_indices) in rule_to_candidates
        code_strings = String[]
        for candidate_idx in candidate_indices
            code = node_to_julia_code(candidate_idx, nodes)
            push!(code_strings, code)
        end
        rule_to_code[rule] = code_strings
    end
    
    return rule_to_code
end

# Get the simplest (shortest) Julia code for each rule
function get_simplest_code_for_rules(nodes::Vector{Node}, rule_to_candidates::Dict{UInt8, Vector{UInt32}})
    rule_to_code = Dict{UInt8, String}()
    
    for (rule, candidate_indices) in rule_to_candidates
        if isempty(candidate_indices)
            continue
        end
        
        # Find the shortest code representation
        shortest_code = ""
        shortest_length = typemax(Int)
        
        for candidate_idx in candidate_indices
            code = node_to_julia_code(candidate_idx, nodes)
            if length(code) < shortest_length
                shortest_code = code
                shortest_length = length(code)
            end
        end
        
        rule_to_code[rule] = shortest_code
    end
    
    return rule_to_code
end

# Display summary of rules with solutions
function display_rule_summary(nodes::Vector{Node}, rule_to_candidates::Dict{UInt8, Vector{UInt32}})
    rules_with_solutions = UInt8[]
    rules_without_solutions = UInt8[]
    
    for rule in UInt8(0):UInt8(255)
        if haskey(rule_to_candidates, rule) && !isempty(rule_to_candidates[rule])
            push!(rules_with_solutions, rule)
        else
            push!(rules_without_solutions, rule)
        end
    end
    
    println("\n=== Rule Summary ===")
    println("Rules with solutions: $(length(rules_with_solutions))")
    println("Rules without solutions: $(length(rules_without_solutions))")
    
    if !isempty(rules_without_solutions)
        println("\nRules without solutions:")
        println(rules_without_solutions)
    end
    
    return rules_with_solutions, rules_without_solutions
end

# Save simplest code for all rules to a file
function save_rule_formulas(filename::String, nodes::Vector{Node}, rule_to_candidates::Dict{UInt8, Vector{UInt32}})
    simplest = get_simplest_code_for_rules(nodes, rule_to_candidates)
    
    open(filename, "w") do io
        println(io, "# Elementary Cellular Automaton Rule Formulas")
        println(io, "# Generated using optimised Node-based computation tree")
        println(io, "")
        
        for rule in UInt8(0):UInt8(255)
            if haskey(simplest, rule)
                println(io, "Rule $(Int(rule)): $(simplest[rule])")
            else
                println(io, "Rule $(Int(rule)): NO SOLUTION FOUND")
            end
        end
    end
    
    println("Saved rule formulas to $filename")
end