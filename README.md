# optimisation-series-code
A "real world" example of optimising a provided algorithm


## Steps Taken

1. Convert `numerics` function to Julia, by copying and pasting the code, changing the syntax, and updating to 1 based indexing.
2. Write code to call the Python code from Julia so that the answers can be compared. This means creating a virtual environment: `python -m venv .venv` and then installing `PyCall` and setting `ENV["PYTHON"]` to point at the correct interpreter and running `] build PyCall`. 
3. Check to see if the results are the same and fix any mistakes - this is an automated way of doing the testing
4. Run benchmarks to compare the initial implementation and the original python implementation
5. Extrapolate results in the benchmark to estimate how long a much larger input would take
6. Optimise the low-hanging fruit -> i.e. reduce allocations and reuse memory and remove redundant operations, ensure type safety etc
7. Understand the code, what can you make better? What are the limitations (i.e. memory). Explore options (like BitVectors). Could use something like StaticArrays?
8. Switch to a different representation - Int64 (or Int32) instead of Vector{Bool}. Use bitwise operations, with some conversion.
9. Use smarter algorithms (memory-less) by using hare and tortoise to detect cycles (at the cost of more computation)
10. Fully parallelise the code, using more compute
11. Run on the GPU or on the HPC easily with Julia
12. Testing - what is the fastest time?
13. Conclusions - what optimisations helped the most?