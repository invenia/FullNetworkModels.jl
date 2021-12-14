# FullNetworkModels

[FullNetworkModels.jl](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/) creates full network models using [JuMP.jl](https://github.com/jump-dev/JuMP.jl) from the [PowerSystems.jl](https://nrel-siip.github.io/PowerSystems.jl) `System` built in [FullNetworkDataPrep.jl](https://gitlab.invenia.ca/invenia/research/FullNetworkDataPrep.jl).

To run simulations with these models, see [FullNetworkSimulations.jl](https://invenia.pages.invenia.ca/research/FullNetworkSimulations.jl/).

## Example

You can model MISO market clearing processes with [the template formulations](@ref templates),
for example:
```julia
using Cbc  # MIP solver
using Clp  # LP solver
using Dates
using ElectricityMarkets
using FullNetworkDataPrep
using FullNetworkModels
using JuMP

date = Date(2020, 08, 06)
da_system = build_system(MISO, DA, date)  # requires NDA access
uc_model = unit_commitment(da_system, Cbc.Optimizer)
optimize!(uc_model)

rt_system = build_system(MISO, RT, date)
ed_model = economic_dispatch(rt_system, Clp.Optimizer)
optimize!(ed_model)
```

To build your own models, you can use the [modelling functions](@ref modelling).

!!! note "Formulations are based on MISO"
    The current version of the package is based on our formulation of the **MISO**
    [day-ahead](https://drive.google.com/file/d/1ruSRtcLl9oicaJtZqWPI8S28sHW2C8Ji/view) and
    [real-time](https://drive.google.com/file/d/1IhAv-Djqc72RPXsB3JBzWYYYbcpw8_0q/view)
    market clearing processes.

## Notation
The documentation and the code itself tries to use consistent and precise notation to describe what is being modelled.
See the [notation page](notation.md) for an overview.

## Contributing guidelines
FullNetworkModels.jl aims to make it easy for researchers to contribute.
To get started, please check the [contributing page](contributing.md) for an overview on the design choices and conventions of the package.

## API
```@contents
Depth = 3
Pages = [
    "api/types.md",
    "api/templates.md",
    "api/modelling.md",
    "api/feasibility.md",
    "api/accessors.md",
    "api/internals.md",
]
```
