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
- `model::Model` (optional): The `JuMP.Model` describing the optimization problem.
    Defaults to an empty model, with `set_string_names_on_creation(model) == false` .
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
    model = Model()
    set_string_names_on_creation(model, false)
    return FullNetworkModel{T}(system, model, datetimes)
end

function FullNetworkModel{T}(system::System, datetime::DateTime) where T<:UCED
    model = Model()
    set_string_names_on_creation(model, false)
    return FullNetworkModel{T}(system, model, [datetime])
end

function FullNetworkModel{T}(
    system::System, solver, datetimes=get_forecast_timestamps(system)
) where T<:UCED
    model = Model(solver)
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
    print(io, "\nSystem: $(length(get_components(Component, fnm.system))) components")
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
