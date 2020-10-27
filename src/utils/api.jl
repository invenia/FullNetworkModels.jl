"""
    FullNetworkModel

Structure containing all the information on the full network model. Contains the JuMP
`model`, the PowerSystems `system`, and a set of `params` that indicate the properties of
the model formulation.

A FullNetworkModel can be initialized using `FullNetworkModel(system::System, solver)`,
which creates an empty JuMP model and empty parameter dictionary.
"""
struct FullNetworkModel
    model::Model
    system::System
    params::Dict
end
FullNetworkModel(system::System, solver) = FullNetworkModel(Model(solver), system, Dict())

# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::FullNetworkModel)
    println(io, "FullNetworkModel")
    println(io, "Model formulation: $(num_variables(fnm.model)) variables")
    println(io, "System: $(length(get_components(Component, fnm.system))) components, $(get_forecasts_horizon(fnm.system)) time periods")
    return nothing
end
