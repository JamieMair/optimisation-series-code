# optimisation-series-code
A "real world" example of optimising a provided algorithm


## Steps Taken

1. Convert `numerics` function to Julia, by copying and pasting the code, changing the syntax, and updating to 1 based indexing.
2. Write code to call the Python code from Julia so that the answers can be compared. This means creating a virtual environment: `python -m venv .venv` and then installing `PyCall` and setting `ENV["PYTHON"]` to point at the correct interpreter and running `] build PyCall`. 