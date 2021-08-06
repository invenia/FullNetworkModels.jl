# FullNetworkModels

FullNetworkModels.jl creates full network models using [JuMP.jl](https://github.com/jump-dev/JuMP.jl) from the [PowerSystems.jl](https://nrel-siip.github.io/PowerSystems.jl) `System` built in [FullNetworkDataPrep.jl](https://gitlab.invenia.ca/invenia/research/FullNetworkDataPrep.jl).

## Notation

The notation used in the code tries to follow the one used in Invenia's formulation of MISO day-ahead market clearing ([PDF](https://drive.google.com/file/d/1ruSRtcLl9oicaJtZqWPI8S28sHW2C8Ji/view)) ([editable version](https://www.overleaf.com/project/5f2453fd81a39d000135af50)) whenever possible, but some differences might exist. (TODO: [create a notation page for the package](https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/issues/22))

# Contributing guidelines
Please check the [Contributing guidelines](contributing.md) for an overview on the design choices and conventions of the package.

## Contents
```@contents
Depth = 3
Pages = [
    "api/types.md",
    "api/templates.md",
    "api/modelling.md",
    "api/feasibility.md",
    "api/accessors.md",
    "api/internals.md",
    "contributing.md",
]
```
