"""
    _add_to_objective!(model::Model, expr)

Adds the expression `expr` to the current objective of `model`.
"""
function _add_to_objective!(model::Model, expr)
    obj = objective_function(model)
    add_to_expression!(obj, expr)
    @objective(model, Min, obj)
    return model
end

"""
    _obj_thermal_linear_cost(fnm::FullNetworkModel, var::Symbol, f)

Adds a linear cost (cost * variable) to the objective, where the cost is fetched by function
`f` and the variable is named `var` within `fnm.model`.
"""
function _obj_thermal_linear_cost!(
    fnm::FullNetworkModel, var::Symbol, f;
    unit_codes=get_unit_codes(ThermalGen, fnm.system)
)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, var)
    n_periods = get_forecast_horizon(system)
    cost = f(system)
    x = model[var]
    obj_cost = sum(cost[g][t] * x[g, t] for g in unit_codes, t in 1:n_periods)
    _add_to_objective!(model, obj_cost)
    return fnm
end

"""
    _offer_curve_properties(offer_curves, n_periods) -> Dict, Dict, Dict

Returns dictionaries for several properties of offer curves, namely the prices, block
generation limits and number of blocks for each generator in each time period. All
dictionaries have the unit codes as keys.
"""
function _offer_curve_properties(offer_curves, n_periods)
    prices = Dict{Int, Vector{Vector{Float64}}}()
    limits = Dict{Int, Vector{Vector{Float64}}}()
    n_blocks = Dict{Int, Vector{Int}}()
    for (g, offer_curve) in offer_curves
        prices[g] = [first.(offer_curve[i]) for i in 1:n_periods]
        limits[g] = [last.(offer_curve[i]) for i in 1:n_periods]
        n_blocks[g] = length.(limits[g])
    end
    # Change block MW values to block limits - e.g. if the MW values are (50, 100, 200),
    # the corresponding limits of each block are (50, 50, 100).
    for g in keys(n_blocks), t in 1:n_periods, q in n_blocks[g][t]:-1:2
        limits[g][t][q] -= limits[g][t][q - 1]
    end
    return prices, limits, n_blocks
end

"""
    _generators_by_reserve_zone(system::System) -> Dict

Returns the unit codes of the generators in each reserve zone.
"""
function _generators_by_reserve_zone(system::System)
    reserve_zones = get_reserve_zones(system)
    gens = collect(get_components(ThermalGen, system))
    reserve_zone_gens = Dict{Int, Vector{Int}}()
    for zone in reserve_zones
        if zone == MARKET_WIDE_ZONE
            reserve_zone_gens[zone] = parse.(Int, get_name.(gens))
        else
            reserve_zone_gens[zone] = parse.(Int, get_name.(
                filter(x -> x.ext["reserve_zone"] == zone, gens)
            ))
        end
    end
    return reserve_zone_gens
end

"""
    generator_dict(f, system::System) -> Dict

Returns a dictionary with the generator properties fetched by PowerSystems API function `f`.
"""
function _generator_dict(f, system::System)
    unit_codes = get_unit_codes(ThermalGen, system)
    gen_dict = Dict{Int, Float64}()
    for unit in unit_codes
        gen = get_component(ThermalGen, system, string(unit))
        gen_dict[unit] = f(gen)
    end
    return gen_dict
end

"""
    _get_service_providers(system::System, service_name::String) -> Vector{Int}

Returns the unit codes of generators that provide the ancillary service with name
`service_name`.
"""
function _get_service_providers(system::System, service_name::String)
    providers = Int[]
    for gen in get_components(ThermalGen, system)
        if service_name in get_name.(gen.services)
            push!(providers, parse(Int, get_name(gen)))
        end
    end
    return providers
end

"""
    _get_resolution_in_minutes(system::System) -> Float64

Returns the time resolution of the time series in the system in minutes.
"""
function _get_resolution_in_minutes(system::System)
    return Minute(get_time_series_resolution(system)).value
end
