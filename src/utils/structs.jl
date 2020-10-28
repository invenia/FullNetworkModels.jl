"""
    ForecastData

Structure containing the forecasts for the system in use. The quantities are organized in
dictionaries wherein the unit codes are the keys.
"""
struct ForecastData
    active_power_min::Dict{Int, Vector{Float64}}
    active_power_max::Dict{Int, Vector{Float64}}
    regulation_min::Dict{Int, Vector{Float64}}
    regulation_max::Dict{Int, Vector{Float64}}
    cost_regulation::Dict{Int, Vector{Float64}}
    cost_spinning::Dict{Int, Vector{Float64}}
    cost_supp_on::Dict{Int, Vector{Float64}}
    cost_supp_off::Dict{Int, Vector{Float64}}
end
function ForecastData()
    return ForecastData(
        Dict(), Dict(), Dict(), Dict(), Dict(), Dict(), Dict(), Dict()
    )
end

"""
    FullNetworkParams

Structure containing relevant parameters of the full network model coming from the system
in use. It's useful to store these parameters because they would otherwise need to be
fetched/calculated multiple times during the construction of the problem.
"""
struct FullNetworkParams
    unit_codes::Vector{Int}
    n_periods::Int
    initial_time::DateTime
    forecasts::ForecastData
end

"""
    _initialize_params(system::System)

Initialize the full network parameters using data from the system. This is useful because
this data would have to be accessed multiple times during the construction of the problem.
"""
function _initialize_params(system::System)
    # Basic properties
    unit_codes = _get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    initial_time = only(get_forecast_initial_times(system))
    # Forecasts
    forecasts = ForecastData()
    for unit in unit_codes
        gen = get_component(ThermalGen, system, string(unit))
        unit_forecasts = values(
            get_forecast(
                Deterministic, gen, initial_time, "get_thermal_params", n_periods
            ).data
        )
        forecasts.active_power_min[unit] = [
            unit_forecasts[i].active_power_min for i in 1:n_periods
        ]
        forecasts.active_power_max[unit] = [
            unit_forecasts[i].active_power_max for i in 1:n_periods
        ]
        forecasts.regulation_min[unit] = [
            unit_forecasts[i].regulation_min for i in 1:n_periods
        ]
        forecasts.regulation_max[unit] = [
            unit_forecasts[i].regulation_max for i in 1:n_periods
        ]
        forecasts.cost_regulation[unit] = [
            unit_forecasts[i].asm_costs.reg for i in 1:n_periods
        ]
        forecasts.cost_spinning[unit] = [
            unit_forecasts[i].asm_costs.spin for i in 1:n_periods
        ]
        forecasts.cost_supp_on[unit] = [
            unit_forecasts[i].asm_costs.sup for i in 1:n_periods
        ]
        forecasts.cost_supp_off[unit] = [
            unit_forecasts[i].asm_costs.sup_off for i in 1:n_periods
        ]
    end
    return FullNetworkParams(unit_codes, n_periods, initial_time, forecasts)
end

"""
    FullNetworkModel

Structure containing all the information on the full network model. Contains the JuMP
`model`, the PowerSystems `system`, and a set of `params` that indicate the properties of
the model formulation.

A FullNetworkModel can be initialized using `FullNetworkModel(system::System, solver)`,
which creates an empty JuMP model and a parameter dictionary based on the `system` data.
"""
struct FullNetworkModel
    model::Model
    system::System
    params::FullNetworkParams
end
function FullNetworkModel(system::System, solver)
    return FullNetworkModel(Model(solver), system, _initialize_params(system))
end
