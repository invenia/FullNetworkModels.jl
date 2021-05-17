# Contributing guidelines

Functions of the package, other than the basic struct definitions, fall mainly under four categories:

## Accessor functions

Accessor functions are aimed at retrieving data from the PowerSystems.jl system so that it can be used when defining the JuMP.jl problem formulation.
These functions generally have the prefix `get_` to follow the convention of PowerSystems.jl.

## Model functions

Model functions are the functions that actually build the JuMP.jl problem formulation.
They are classified in _variable_, _constraint_, or _objective_ functions, and should have a prefix indicating in which category they belong (`var_`, `con_`, and `obj_`, respectively).
Note that sometimes expressions from another category might be added as part of a function, e.g., some variable functions might add constraints.
This might happen because the variables that are being created only make sense when accompanied by some basic constraints (see [`var_startup_shutdown`](@ref) for an example).

## Template functions

Template functions are simply collections of model function calls in order to facilitate the definition of problems by users.

## Latex functions

Latex functions are used to provide clearer documentation of the template problem formulations and the expressions created by each model function.
These functions simply write the Latex expressions that defined by their corresponding function, which can then be read in rich-text environment.