# FullNetworkModels

[FullNetworkModels.jl](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/) creates full network models using [JuMP.jl](https://github.com/jump-dev/JuMP.jl) from the [FullNetworkSystems.jl](https://github.com/invenia/FullNetworkSystems.jl) `System` built in [FullNetworkDataPrep.jl](https://gitlab.invenia.ca/invenia/research/FullNetworkDataPrep.jl).

To run simulations with these models, see [FullNetworkSimulations.jl](https://invenia.pages.invenia.ca/research/FullNetworkSimulations.jl/).

## Example

You can model MISO market clearing processes with [the template formulations](@ref templates),
for example:
```julia
using Dates
using ElectricityMarkets
using FullNetworkDataPrep
using FullNetworkModels
using HiGHS  # solver
using JuMP

date = Date(2020, 08, 06)
da_system = build_system(MISO, DA, date)  # requires NDA access
uc_model = unit_commitment(MISO, da_system, HiGHS.Optimizer)
optimize!(uc_model)

rt_system = build_system(MISO, RT, date)
ed_model = economic_dispatch(MISO, rt_system, HiGHS.Optimizer)
optimize!(ed_model)
```

Alternatively, you can define the formulation using [the `UnitCommitment` and `EconomicDispatch` types](@ref types), and use them to build the JuMP model.
This is especially useful when working with a higher-level API such as FullNetworkSimulations.jl, since you can specify just the formulation type without having to directly deal with the JuMP problem.
For example, the two steps below are equivalent to the one-liner `fnm = unit_commitment(MISO, system, solver; branch_flows=true)`:

```julia
uc = UnitCommitment(branch_flows=true)
fnm = uc(MISO, system, HiGHS.Optimizer)
```

To build your own models, you can use the [modelling functions](@ref modelling).

!!! note "Formulations are based on MISO"
    The current version of the package is based on our formulation of the **MISO**
    [day-ahead](https://drive.google.com/file/d/1ruSRtcLl9oicaJtZqWPI8S28sHW2C8Ji/view) and
    [real-time](https://drive.google.com/file/d/1IhAv-Djqc72RPXsB3JBzWYYYbcpw8_0q/view)
    market clearing processes.

## [Using soft constraints](@id soft_constraints)

Templates accept a keyword argument `slack` that can be used to specify the slack penalty to be used by certain constraints, therefore modelling them as soft constraints.
By construction, if the value of the slack penalty is `nothing`, it means the constraint should be modelled as a hard constraint.
The following symbols can be used to specify soft constraints: `:energy_balance`, `:ramp_rates`, `:ancillary_requirements`.

!!! note "Thermal branch constraints"
    Thermal branch constraints are always soft constraints according to the branch data coming from the data prep stage, and this cannot be adjusted using the `slack` kwarg.

There are several ways to specify slack penalties:

To use the default slack options:
```julia
fnm = unit_commitment(system, solver)
```
Note that unit commitment templates default to hard constraints, while economic dispatch defaults to soft constraints.

To use a single slack penalty value across all soft constraints:
```julia
fnm = unit_commitment(system, solver; slack=1e7)
```

To use different slack penalties for specific soft constraints:
```julia
fnm = unit_commitment(system, solver; slack=:energy_balance => 1e7)
```
or
```julia
fnm = unit_commitment(system, solver; slack=[:energy_balance => 1e7, :ramp_rates => 1e6])
```
Note that in the examples above, any constraint not explicitly added as a `Pair` will be set as hard constraint.

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
