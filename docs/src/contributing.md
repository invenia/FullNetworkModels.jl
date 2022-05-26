# Contributing

**FullNetworkModels.jl aims to make it easy for researchers to contribute.**

## Guidelines

We want to prioritise transparency and flexibility of modelling by:
- writing code that closely resembles the mathematical expressions,
- writing one function per mathematical expression or expression group (e.g. one function for generation limits, one function for ancillary limits),
- writing documentation containing the ``\LaTeX``-formatted mathematical expression.

New contributors should make sure to follow the advice in the [ColPrac Contributor Guide](https://github.com/SciML/ColPrac).
In particular, contributions should be made via [merge requests](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/merge_requests), match the existing code style, and include documentation and tests.
To discuss changes before a opening a merge request, please [open an issue](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/issues).

## Navigating the code

Functions of the package, other than the basic [type](@ref types) definitions, fall mainly under four categories: [accessors](@ref accessors), [modelling functions](@ref modelling), [template functions](@ref templates), and [`latex`](@ref FullNetworkModels.latex) methods.

## Accessor functions

Accessor functions, located in `src/utils/accessors.jl`, are aimed at retrieving data from the PowerSystems.jl system so that it can be used when defining the JuMP.jl problem formulation.
These functions generally have the prefix `get_` to follow the convention of PowerSystems.jl.

## Modelling functions

Modelling functions, which are located in `src/model/`, are the functions that actually build the JuMP.jl problem formulation.
They are classified in _variable_, _constraint_, or _objective_ functions, and should have a prefix indicating in which category they belong (`var_`, `con_`, and `obj_`, respectively).

Note that sometimes expressions from another category might be added as part of a function, e.g., some variable functions might add constraints.
This might happen because the variables that are being created only make sense when accompanied by some basic constraints (see [`var_startup_shutdown!`](@ref) for an example).

Model functions generally follow a simple recipe:

1. Use accessor functions to retrieve the system data that is involved in the mathematical expressions to be added.
2. Write the JuMP expressions using the system data and add them to the model.

## Template functions

Template functions, located in `src/templates/`, are simply collections of model function calls in order to facilitate the definition of problems by users.

## ``\LaTeX`` functions

``\LaTeX`` functions are used to provide clearer documentation of the template problem formulations and the expressions created by each model function.
These functions simply write the ``\LaTeX`` expressions that defined by their corresponding function, which can then be read in rich-text environment.
To that end, each model function `foo` should have a corresponding ``\LaTeX`` function that is defined as `latex(::typeof(foo))`.
See, for example, the `latex` methods in the `src/model/` files.

## Tests

Tests generally employ the three-bus fake system provided by the [`FullNetworkDataPrep.TestUtils` submodule](https://invenia.pages.invenia.ca/research/FullNetworkDataPrep.jl/testutils.html).
Tests for model functions can either verify if the optimization results in an expected result, or just check if the expressions were correctly added to the model (e.g. using `sprint` and `constraint_by_name`).
For examples see the existing tests in `test/constraints.jl`.

!!! note "Our models build anonymous variables and constraints by default"
    Our models have `set_string_names_on_creation(model) == false` to [reduce model build times](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/performance_tips/#Disable-string-names).
    This means that individual variables and constraints don't get `String` names when added to the model.
    Since we want to use `variable_by_name` and `constraint_by_name` as part of testing, our tests retroactively add names to variables and constraints.

    See the JuMP documentation on the different meanings of "names" [for variables](https://jump.dev/JuMP.jl/stable/manual/variables/#variable_names_and_bindings) 
    and [for constraints](https://jump.dev/JuMP.jl/stable/manual/constraints/#String-names,-symbolic-names,-and-bindings).
