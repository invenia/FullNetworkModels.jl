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

Return a struct indicating details of the formulation that will be used to solve the unit
commitment. This struct can then be used as a callable to build the JuMP problem by passing
the system and solver.

# Keywords
 - `relax_integrality`: If set to `true`, binary variables will be relaxed.
 - `slack=nothing`: The slack penalty for the soft constraints.
   For more info on specifying slacks, refer to the [docs on soft constraints](@ref soft_constraints).
 - `threshold=$_SF_THRESHOLD`: The threshold (cutoff value) to be applied to the shift factors. Only relevant when `branch_flows=true`.
 - `branch_flows::Bool=false`: Whether or not to inlcude thermal branch flow constraints.
 - `ramp_rates::Bool=true`: Whether or not to include ramp rate constraints.

# Example

```julia
uc = UnitCommitment(
    relax_integrality=true, branch_flows=true, slack=:ramp_rates => 1e3
)
fnm = uc(system, solver)
```

or, equivalently,

```julia
fnm = unit_commitment(
    system, solver; relax_integrality=true, branch_flows=true, slack=:ramp_rates => 1e3
)
```
"""
struct UnitCommitment
    slack::Slacks
    branch_flows::Bool
    ramp_rates::Bool
    threshold::Float64
    relax_integrality::Bool
end

function UnitCommitment(;
    slack=_DEFAULT_UC_SLACK,
    branch_flows=false,
    ramp_rates=true,
    threshold=_SF_THRESHOLD,
    relax_integrality=false,
)
    slack = Slacks(slack)  # if we've an invalid `slack` argument, force error ASAP.
    return UnitCommitment(slack, branch_flows, ramp_rates, threshold, relax_integrality)
end

###
### Economic Dispatch
###

"""
    EconomicDispatch(; keywords...)

Return a callable that receives a `System` and returns a `FullNetworkModel` with the
formulation determined by the given keywords.

# Example

```julia
ed = EconomicDispatch(branch_flows=true)
fnm = ed(system, solver)
```

or, equivalently,

```julia
fnm = economic_dispatch(system, solver; branch_flows=true)
```
"""
struct EconomicDispatch
    slack::Slacks
    branch_flows::Bool
    threshold::Float64
end

function EconomicDispatch(;
    slack=_DEFAULT_ED_SLACK, branch_flows=false, threshold=_SF_THRESHOLD
)
    slack = Slacks(slack)  # if we've an invalid `slack` argument, force error ASAP.
    return EconomicDispatch(slack, branch_flows, threshold)
end

# Shorthand for the UnitCommitment and EconomicDispatch types
const UC = UnitCommitment
const ED = EconomicDispatch
