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

struct UnitCommitment
    slack::Slacks
    branch_flows::Bool
    ramp_rates::Bool
    threshold::Float64
    relax_integrality::Bool
end

struct EconomicDispatch
    slack::Slacks
    branch_flows::Bool
    threshold::Float64
end

# Shorthand for the UnitCommitment and EconomicDispatch types
const UC = UnitCommitment
const ED = EconomicDispatch

"""
    FullNetworkModel{<:Union{UC,ED}}

Structure containing all the information on the full network model. Contains a JuMP.jl
`Model` and a PowerSystems.jl `System` for the period contemplated in `datetimes`.

!!! tip "Use templates"
    A `FullNetworkModel` should usually be constructed via a [formulation template](@ref templates),
    which will build a full optimization problem with objective, variables, and constraints,
    and attach a solver.

---

    FullNetworkModel{<:Union{UC,ED}}(system[, datetimes])
    FullNetworkModel{<:Union{UC,ED}}(system[, model_or_solver, datetimes])

To construct a `FullNetworkModel` for all datetimes in a `System` use
`FullNetworkModel{UC}(system::System)` or `FullNetworkModel{ED}(system::System)`,
depending on if building a [`UC`](@ref) or [`ED`](@ref) problem.

Or to specify exactly which datetimes to model use
`FullNetworkModel{ED}(system::System, datetimes::Vector{DateTime})`.

You can then add variables, constraints, objectives and a solver to this model.

You can also start with a non-empty `JuMP.Model` via `FullNetworkModel{ED}(system, model::Model)`.
Or initialise the empty model with a solver with `FullNetworkModel{ED}(system, solver)`.
But usually it is best to add an appropriate solver using `set_optimizer(fnm, solver)`
only after the model has been built.

# Arguments
- `system::System`: The `PowerSystems.System` containg data on the system to be modelled.
- `model::Model` (optional): The `JuMP.Model` describing the optimization problem.
    Defaults to an empty model, with `set_string_names_on_creation(model) == false` .
- `solver` (optional): A solver constructor to attach to an empty `JuMP.Model`.
- `datetimes::Vector{DateTime}=get_datetimes(system)` (optional): The time periods
  which should be modelled. Must be a subset of the times for which the system has data.
  Defaults to all datetimes in the system.
"""
struct FullNetworkModel{T<:Union{UC,ED}}
    system::System
    model::Model
    datetimes::Vector{DateTime}
    function FullNetworkModel{T}(
        system::System, model::Model, datetimes=get_datetimes(system)
    ) where T<:Union{UC,ED}
        new{T}(system, model, datetimes)
    end
end

function FullNetworkModel{T}(
    system::System, model::Model, datetime::DateTime
) where T<:Union{UC,ED}
    return FullNetworkModel{T}(system, model, [datetime])
end

function FullNetworkModel{T}(
    system::System, datetimes::AbstractVector{<:DateTime}=get_datetimes(system)
) where T<:Union{UC,ED}
    model = Model()
    set_string_names_on_creation(model, false)
    return FullNetworkModel{T}(system, model, datetimes)
end

function FullNetworkModel{T}(system::System, datetime::DateTime) where T<:Union{UC,ED}
    model = Model()
    set_string_names_on_creation(model, false)
    return FullNetworkModel{T}(system, model, [datetime])
end

function FullNetworkModel{T}(
    system::System, solver, datetimes=get_datetimes(system)
) where T<:Union{UC,ED}
    model = Model(solver; add_bridges=false)
    set_string_names_on_creation(model, false)
    return FullNetworkModel{T}(system, model, datetimes)
end

# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::T) where {T <: FullNetworkModel}
    print(io, T)
    # Time
    min, max = extrema(fnm.datetimes)
    if get(io, :compact, false)::Bool
        min == max ? print(io, "(", min, ")") : print(io, "(", min, " … ", max, ")")
        return nothing
    end
    min == max ? print(io, "\nTime period: ", min) : print(io, "\nTime periods: ", min, " to ", max)
    # System
    num_components = sum(
        length(c) for c in [
            get_buses(fnm.system), get_generators(fnm.system), get_branches(fnm.system)
        ]
    )
    print(io, "\nSystem: $(num_components) components")
    # Model
    n_vars = num_variables(fnm.model)
    con_list = list_of_constraint_types(fnm.model)
    n_cons = isempty(con_list) ? 0 : sum(num_constraints(fnm.model, F, S) for (F, S) in con_list)
    print(io, "\nModel formulation: $n_vars variables and $n_cons constraints")
    n_vars == n_cons == 0 && return nothing
    var_names, con_names = _names(fnm.model)
    if !isempty(var_names)  # variables/constraints don't have to have names
        print(io, "\n  Variable names: ")
        if get(io, :color, false)::Bool
            printstyled(io, join(var_names, ", "); color=Base.info_color())
        else
            join(io, var_names, ", ")
        end
    end
    if !isempty(con_names)
        print(io, "\n  Constraint names: ")
        if get(io, :color, false)::Bool
            printstyled(io, join(con_names, ", "); color=Base.info_color())
        else
            join(io, con_names, ", ")
        end
    end
    return nothing
end

function _names(model::Model)
    var_names = Symbol[]
    con_names = Symbol[]
    for (name, val) in object_dictionary(model)
        _is_constraint(val) ? push!(con_names, name) : push!(var_names, name)
    end
    return sort(var_names), sort(con_names)
end

_is_constraint(x::T) where T <: Union{ConstraintRef,VariableRef} = _is_constraint(T)
_is_constraint(x) = _is_constraint(eltype(x))
_is_constraint(::Type{<:ConstraintRef}) = true
_is_constraint(::Type) = false
