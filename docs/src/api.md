# API

## Types

```@docs
FullNetworkModel
UCED
UC
ED
```

## [Templates](@id templates)

### Unit Commitment

```@autodocs
Modules = [FullNetworkModels]
Pages = ["templates/unit_commitment.jl"]
Private = false
```

## Variables

```@autodocs
Modules = [FullNetworkModels]
Pages = ["model/variables.jl"]
Private = false
```

## Objective Terms

```@autodocs
Modules = [FullNetworkModels]
Pages = ["model/objectives.jl"]
Private = false
```

## Constraints

```@autodocs
Modules = [FullNetworkModels]
Pages = ["model/constraints.jl"]
Private = false
```

## Accessors

```@autodocs
Modules = [FullNetworkModels]
Pages = ["utils/accessors.jl"]
Private = false
```

## Feasibility checks

```@autodocs
Modules = [FullNetworkModels]
Pages = ["utils/feasibility_checks.jl"]
Private = false
```

## Internals

These functions are not public API, they may change or be removed at any time.

```@autodocs
Modules = [FullNetworkModels]
Public = false
```
