"""
    UCED

Abstract type describing unit commitment and economic dispatch.
"""
abstract type UCED end

"""
    UC

Abstract type describing unit commitment.
"""
abstract type UC <: UCED end

"""
    ED

Abstract type describing economic dispatch.
"""
abstract type ED <: UCED end

"""
    FullNetworkModel{<:UCED}

Structure containing all the information on the full network model. Contains a JuMP.jl
`Model` and a PowerSystems.jl `System` for the period contemplated in `datetimes`.

!!! tip "Use templates"
    A `FullNetworkModel` should usually be constructed via a [formulation template](@ref templates),
    which will build a full optimization problem with objective, variables, and constraints,
    and attach a solver.

---

    FullNetworkModel{<:UCED}(system[, datetimes])
    FullNetworkModel{<:UCED}(system[, model_or_solver, datetimes])

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
- `model::Model=Model()` (optional): The `JuMP.Model` describing the optimization problem.
  Defaults to an empty model.
- `solver` (optional): A solver constructor to attach to an empty `JuMP.Model`.
- `datetimes::Vector{DateTime}=get_forecast_timestamps(system)` (optional): The time periods
  which should be modelled. Must be a subset of the times for which the system has data.
  Defaults to all datetimes in the system (see [`get_forecast_timestamps`](@ref)).
"""
struct FullNetworkModel{T<:UCED}
    system::System
    model::Model
    datetimes::Vector{DateTime}
    function FullNetworkModel{T}(
        system::System, model::Model, datetimes=get_forecast_timestamps(system)
    ) where T<:UCED
        new{T}(system, model, datetimes)
    end
end

function FullNetworkModel{T}(
    system::System, model::Model, datetime::DateTime
) where T<:UCED
    return FullNetworkModel{T}(system, model, [datetime])
end

function FullNetworkModel{T}(
    system::System, datetimes::AbstractVector{<:DateTime}=get_forecast_timestamps(system)
) where T<:UCED
    return FullNetworkModel{T}(system, Model(), datetimes)
end

function FullNetworkModel{T}(system::System, datetime::DateTime) where T<:UCED
    return FullNetworkModel{T}(system, Model(), [datetime])
end

function FullNetworkModel{T}(
    system::System, solver, datetimes=get_forecast_timestamps(system)
) where T<:UCED
    return FullNetworkModel{T}(system, Model(solver), datetimes)
end

# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::FullNetworkModel{T}) where T
    println(io, typeof(fnm))
    if length(fnm.datetimes) > 1
        println(io, "Time periods: $(first(fnm.datetimes)) to $(last(fnm.datetimes))")
    else
        println(io, "Time periods: $(only(fnm.datetimes))")
    end
    n_vars = num_variables(fnm.model)
    con_list = list_of_constraint_types(fnm.model)
    n_cons = if isempty(con_list)
        0
    else
        sum(num_constraints(fnm.model, F, S) for (F, S) in con_list)
    end
    println(io, "Model formulation: $n_vars variables and $n_cons constraints")
    println(io, "System: $(length(get_components(Component, fnm.system))) components")
    return nothing
end
