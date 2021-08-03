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

Structure containing all the information on the full network model. Contains the JuMP
`model` and the PowerSystems `system` data for the period contemplated in `datetimes`.

Can be initialized using `FullNetworkModel(system::System, solver, datetimes)`, which
creates an empty JuMP model related to `system` using the desired `solver`.
"""
struct FullNetworkModel{T<:UCED}
    system::System
    model::Model
    datetimes::Vector{DateTime}
    function FullNetworkModel{T}(
        system::System,
        model::Model,
        datetimes::AbstractVector{<:DateTime}=get_forecast_timestamps(system)
    ) where T<:UCED
        new{T}(system, model, datetimes)
    end
end

function FullNetworkModel{T}(
    system::System, datetimes::AbstractVector{<:DateTime}=get_forecast_timestamps(system)
) where T<:UCED
    return FullNetworkModel{T}(system, Model(), datetimes)
end

function FullNetworkModel{T}(
    system::System, solver, datetimes::AbstractVector{<:DateTime}=get_forecast_timestamps(system)
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
