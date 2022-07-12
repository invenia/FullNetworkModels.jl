const _DEFAULT_UC_SLACK = nothing
const _DEFAULT_ED_SLACK = 1e6

"""
    Slacks(values)

Represents the slack penalties for each soft constraint.

The value `nothing` means "no slack" i.e. a hard constraint.

# Examples
- All values are `nothing` by default:
  ```julia
  julia> Slacks()
  Slacks:
    energy_balance = nothing
    ramp_rates = nothing
    ancillary_requirements = nothing
  ```

- If `values` is a single value (including `nothing`), set all slack penalties to that value:
  ```julia
  julia> Slacks(1e-3)
  Slacks:
    energy_balance = 0.001
    ramp_rates = 0.001
    ancillary_requirements = 0.001
  ```

- If `values` is a `Pair` or collection of `Pair`s, then the values are set according to the
  specifications in the pairs:
  ```julia
  julia> Slacks(:ramp_rates => 1e-3)
  Slacks:
    energy_balance = nothing
    ramp_rates = 0.001
    ancillary_requirements = nothing

  julia> Slacks([:ramp_rates => 1e-3, :ancillary_requirements => 1e-4])
  Slacks:
    energy_balance = nothing
    ramp_rates = 0.001
    ancillary_requirements = 0.0001
  ```
"""
Base.@kwdef struct Slacks
    energy_balance::Union{Float64, Nothing}=nothing
    ramp_rates::Union{Float64, Nothing}=nothing
    ancillary_requirements::Union{Float64, Nothing}=nothing
end

function Slacks(slacks::Union{Number,Nothing})
    names = fieldnames(Slacks)
    N = fieldcount(Slacks)
    return Slacks(NamedTuple{names}(ntuple(_ -> slacks, N)))
end
Slacks(slack::Pair{Symbol}) = Slacks(tuple(slack))
Slacks(itr...) = Slacks(NamedTuple(itr...))
Slacks(nt::NamedTuple) = Slacks(; nt...)
Slacks(sl::Slacks) = sl

###
### Unit Commitment
###

"""
    UnitCommitment(; keywords...)

Type defining the unit commitment formulation.
Return a callable that receives a `System` and returns a `FullNetworkModel` with the given formulation.

# Keywords
 - `relax_integrality`: If set to `true`, binary variables will be relaxed.
 - `slack=$(FullNetworkModels._DEFAULT_UC_SLACK)`: The slack penalty for the soft constraints.
   For more info on specifying slacks, refer to the [docs on soft constraints](@ref soft_constraints).
 - `branch_flows::Bool=false`: Whether or not to inlcude thermal branch flow constraints.
 - `threshold=$_SF_THRESHOLD`: The threshold (cutoff value) to be applied to the shift factors. Only relevant when `branch_flows=true`.
 - `ramp_rates::Bool=true`: Whether or not to include ramp rate constraints.

# Example

```julia
uc = UnitCommitment(
    relax_integrality=true, branch_flows=true, slack=:ramp_rates => 1e3
)
fnm = uc(MISO, system, solver)
```
"""
struct UnitCommitment
    slack::Slacks
    branch_flows::Bool
    ramp_rates::Bool
    threshold::Float64
    relax_integrality::Bool
end

const UC = UnitCommitment

function UnitCommitment(;
    slack=_DEFAULT_UC_SLACK,
    branch_flows::Bool=false,
    ramp_rates::Bool=true,
    threshold::Number=_SF_THRESHOLD,
    relax_integrality::Bool=false,
)
    slack = Slacks(slack)
    return UnitCommitment(slack, branch_flows, ramp_rates, threshold, relax_integrality)
end

###
### Economic Dispatch
###

"""
    EconomicDispatch(; keywords...)

Type defining the economic dispatch formulation.
Return a callable that receives a `System` and returns a `FullNetworkModel` with the given formulation.

# Keywords
 - `slack=$(FullNetworkModels._DEFAULT_ED_SLACK)`: The slack penalty for the soft constraints.
   For more info on specifying slacks, refer to the [docs on soft constraints](@ref soft_constraints).
 - `branch_flows::Bool=false`: Whether or not to inlcude thermal branch flow constraints.
 - `threshold=$_SF_THRESHOLD`: The threshold (cutoff value) to be applied to the shift factors.
   Only relevant when `branch_flows=true`.


# Example

```julia
ed = EconomicDispatch(branch_flows=true)
fnm = ed(MISO, system, solver)
```
"""
struct EconomicDispatch
    slack::Slacks
    branch_flows::Bool
    threshold::Float64
end

const ED = EconomicDispatch

function EconomicDispatch(;
    slack=_DEFAULT_ED_SLACK, branch_flows=false, threshold=_SF_THRESHOLD
)
    slack = Slacks(slack)
    return EconomicDispatch(slack, branch_flows, threshold)
end
