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
    datetimes::Vector{DateTime}
end

function FullNetworkModel(system::System, solver, datetimes)
    return FullNetworkModel(Model(solver), system, datetimes)
end

# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::FullNetworkModel)
    if length(fnm.dastetimes > 1)
        println(io, "FullNetworkModel defined for $(first(fnm.datetimes)) to $(last(fnm.datetimes))")
    else
        println(io, "FullNetworkModel defined for $(only(fnm.datetimes))")
    end
    n_vars = num_variables(fnm.model)
    n_cons = sum(
        num_constraints(fnm.model, F, S) for (F, S) in list_of_constraint_types(fnm.model)
    )
    println(io, "Model formulation: $n_vars variables and $n_cons constraints")
    println(io, "System: $(length(get_components(Component, fnm.system))) components, $(get_forecast_horizon(fnm.system)) time periods")
    return nothing
end
