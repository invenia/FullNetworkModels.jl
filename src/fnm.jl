"""
    FullNetworkModel

Structure containing all the information on the full network model. Contains the JuMP
`model` and the PowerSystems `system`.

A FullNetworkModel can be initialized using `FullNetworkModel(system::System, solver)`,
which creates an empty JuMP model related to `system` using the desired `solver`.
"""
struct FullNetworkModel
    model::Model
    system::System
end

function FullNetworkModel(system::System, solver)
    return FullNetworkModel(Model(solver), system)
end

# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::FullNetworkModel)
    println(io, "FullNetworkModel")
    println(io, "Model formulation: $(num_variables(fnm.model)) variables")
    println(io, "System: $(length(get_components(Component, fnm.system))) components, $(get_forecast_horizon(fnm.system)) time periods")
    return nothing
end

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
