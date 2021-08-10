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
    _variable_cost(model::Model, names, datetimes, n_blocks, Λ, v, sense) -> AffExpr

Defines the expression of a variable cost to be added in the objective function.

Arguments:
 - `model::Model`: the JuMP model that contains the variables to be used.
 - `names`: the unit codes, bid names, or similar that act as indices.
 - `datetimes`: the time periods considered.
 - `Λ`: The offer/bid prices per block.
 - `v`: The name of the variable to be considered in the cost, e.g. `:p` for generation.
 - `sense`: constant multiplying the variable cost; should be 1 or -1 (i.e. if it's a
   positive or negative expression).
"""
function _variable_cost(model::Model, names, datetimes, n_blocks, Λ, v, sense)
    v_aux = model[Symbol(v, :_aux)]
    variable_cost = AffExpr(0.0)
    for n in names, t in datetimes, q in 1:n_blocks[n, t]
        # Faster version of `variable_cost += Λ[n, t][q] * v_aux[n, t, q]`
        add_to_expression!(variable_cost, Λ[n, t][q], v_aux[n, t, q])
    end
    # Apply sense to expression - same as `variable_cost *= sense`
    map_coefficients_inplace!(x -> sense * x, variable_cost)
    return variable_cost
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
    cost = f(fnm.system, fnm.datetimes)
    x = model[var]
    obj_cost = AffExpr()
    for g in unit_codes, t in fnm.datetimes
        add_to_expression!(obj_cost, cost[g, t], x[g, t])
    end
    _add_to_objective!(model, obj_cost)
    return fnm
end

"""
    _curve_properties(curves; blocks=false) -> DenseAxisArray, DenseAxisArray, DenseAxisArray

Returns DenseAxisArrays for several properties of offer/bid curves, namely the prices, block
MW limits and number of blocks for each component in each time period. All arrays have unit
codes/bid names and datetimes as axes, respectively. The kwarg `blocks` indicates if the
curve is just a series of blocks, meaning the MW values represent the size of the blocks
instead of the cumulative MW value in the curve.
"""
function _curve_properties(curves; blocks=false)
    prices = map(x -> first.(x), curves)
    limits = map(x -> last.(x), curves)
    n_blocks = map(length, limits)
    if !blocks
        # Change curve MW values to block MW limits - e.g. if the MW values are
        # (50, 100, 200), the corresponding MW limits of each block are (50, 50, 100).
        for lim in limits, q in length(lim):-1:2
            @inbounds lim[q] -= lim[q - 1]
        end
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
    return Dates.value(Minute(get_time_series_resolution(system)))
end

"""
    _time_series_values(device, label::AbstractString, datetimes::Vector{DateTime}) -> Vector

Returns the valuesc in `device` of the time series named `label` for the time periods in
`datetimes`.
"""
function _time_series_values(device, label::AbstractString, datetimes::Vector{DateTime})
    ta = get_time_series_array(SingleTimeSeries, device, label)
    return values(ta[datetimes])
end

"""
    _generator_time_series_values(
        gen, label::AbstractString, datetimes::Vector{DateTime}, suffix::Bool
    ) -> Union{Nothing, Vector}

Returns the values in `gen` of the time series named `label`, if it exists, for the time
periods in `datetimes`. If `suffix` is set to `true`, then the reserve zone is considered.
"""
function _generator_time_series_values(
    gen, label::AbstractString, datetimes::Vector{DateTime}, suffix::Bool
)
    # If the label is supposed to have a zone suffix, append it
    full_label = suffix ? label * "_$(gen.ext["reserve_zone"])" : label
    # Return values only if the unit actually has that time series
    if full_label in get_time_series_names(SingleTimeSeries, gen)
        return _time_series_values(gen, full_label, datetimes)
    end
    return nothing
end

"""
    _load_time_series_values(load, datetimes::Vector{DateTime}) -> Vector

Returns the values in `load` of the "active_power" time series for the time periods in
`datetimes`, multiplied by the base `active_power` field value.
"""
function _load_time_series_values(load, datetimes::Vector{DateTime})
    active_power = get_active_power(load)
    return active_power .* _time_series_values(load, "active_power", datetimes)
end
