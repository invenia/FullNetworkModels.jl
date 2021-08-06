# Contributing


**FullNetworkModels.jl aims to make it easy for researchers to contribute.**

We want to prioritise transparency and flexibility of modelling by:
- writing code that closely resembles the mathematical expressions,
- writing one function per mathematical expression or expression group (e.g. one function for generation limits, one function for ancillary limits),
- writing documentation containing the ``\LaTeX``-formatted mathematical expression.

## Guidelines

New contributors should make sure to follow the advice in the [ColPrac Contributor Guide](https://github.com/SciML/ColPrac).
In particular, contributions should be made via [merge requests](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/merge_requests), match the existing code style, and include documentation and tests.
To discuss changes before a opening a merge request, please [open an issue](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/issues).

## Functions

Functions of the package, other than the basic struct definitions, fall mainly under four categories:

### Accessor functions

Accessor functions, located in `src/utils/accessors.jl`, are aimed at retrieving data from the PowerSystems.jl system so that it can be used when defining the JuMP.jl problem formulation.
These functions generally have the prefix `get_` to follow the convention of PowerSystems.jl.

### Modelling functions

Modelling functions, which are located in `src/model/`, are the functions that actually build the JuMP.jl problem formulation.
They are classified in _variable_, _constraint_, or _objective_ functions, and should have a prefix indicating in which category they belong (`var_`, `con_`, and `obj_`, respectively).

Note that sometimes expressions from another category might be added as part of a function, e.g., some variable functions might add constraints.
This might happen because the variables that are being created only make sense when accompanied by some basic constraints (see [`var_startup_shutdown!`](@ref) for an example).

Model functions generally follow a simple recipe:

1. Use accessor functions to retrieve the system data that is involved in the mathematical expressions to be added.
2. Write the JuMP expressions using the system data and add them to the model.

### Template functions

Template functions, located in `src/templates/`, are simply collections of model function calls in order to facilitate the definition of problems by users.

### ``\LaTeX`` functions

``\LaTeX`` functions are used to provide clearer documentation of the template problem formulations and the expressions created by each model function.
These functions simply write the ``\LaTeX`` expressions that defined by their corresponding function, which can then be read in rich-text environment.
To that end, each model function `foo` should have a corresponding ``\LaTeX`` function that is defined as `_latex(::typeof(foo))`.
See, for example, the `_latex` methods in the `src/model/` files.

## Tests

Tests generally employ the three-bus fake system provided by the TestUtils submodule of FullNetworkDataPreps.jl.
Tests for model functions can either verify if the optimization results in an expected result, or just check if the expressions were correctly added to the model (e.g. using `sprint` and `constraint_by_name`).
For examples see the existing tests in `test/constraints.jl`.
