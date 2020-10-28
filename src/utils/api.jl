# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::FullNetworkModel)
    println(io, "FullNetworkModel")
    println(io, "Model formulation: $(num_variables(fnm.model)) variables")
    println(io, "System: $(length(get_components(Component, fnm.system))) components, $(get_forecasts_horizon(fnm.system)) time periods")
    return nothing
end
