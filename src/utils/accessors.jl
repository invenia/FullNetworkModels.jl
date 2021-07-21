"""
    has_variable(model::Model, var) -> Bool

Returns `true` if `model` contains a variable named `var` and `false` otherwise.
"""
function has_variable(model::Model, var::Symbol)
    obj_dict = object_dictionary(model)
    return haskey(obj_dict, var) && eltype(obj_dict[var]) <: VariableRef
end
has_variable(model::Model, var::String) = has_variable(model, Symbol(var))

"""
    has_constraint(model::Model, con) -> Bool

Returns `true` if `model` contains a constraint named `con` and `false` otherwise.
"""
function has_constraint(model::Model, con::Symbol)
    obj_dict = object_dictionary(model)
    return haskey(obj_dict, con) && eltype(obj_dict[con]) <: ConstraintRef
end
has_constraint(model::Model, con::String) = has_constraint(model, Symbol(con))

"""
    get_unit_codes(gentype::Type{<:Generator}, system::System) -> Vector{Int}

Returns the unit codes of all generators in `system` under type `gentype`.
"""
function get_unit_codes(gentype::Type{<:Generator}, system::System)
    return parse.(Int, get_name.(get_components(gentype, system)))
end

"""
    get_bid_names(bidtype::Type{<:Device}, system::System)

Returns the names of the bids in `system` that are of type `bidtype`.
"""
function get_bid_names(bidtype::Type{<:Device}, system::System)
    return get_name.(get_components(bidtype, system))
end

"""
    get_load_names(loadtype::Type{<:StaticLoad}, system::System) -> Vector{String}

Returns the names of all loads in `system` under type `loadtype`.
"""
function get_load_names(loadtype::Type{<:StaticLoad}, system::System)
    return get_name.(get_components(loadtype, system))
end

"""
    get_generator_time_series(system::System, label::AbstractString; suffix=false) -> Dict

Returns a dictionary with the time series values for `label` stored in `system`. The keys
of the dictionary are the unit codes. If the label is supposed to have a zone suffix, e.g.
for ancillary costs, then `suffix` should be set to `true`.
"""
function get_generator_time_series(system::System, label::AbstractString; suffix=false)
    unit_codes = get_unit_codes(ThermalGen, system)
    ts_dict = Dict{Int, Vector}()
    for unit in unit_codes
        gen = get_component(ThermalGen, system, string(unit))
        # If the label is supposed to have a zone suffix, append it
        full_label = suffix ? label * "_$(gen.ext["reserve_zone"])" : label
        # Add the dict entry only if the unit actually has that time series
        if full_label in get_time_series_names(SingleTimeSeries, gen)
            ts_dict[unit] = get_time_series_values(SingleTimeSeries, gen, full_label)
        end
    end
    return ts_dict
end

"""
    get_fixed_loads(system::System) -> Dict

Returns a dictionary with the fixed load forecasts stored in `system`. The keys of the
dictionary are the load names.
"""
function get_fixed_loads(system::System)
    ts_dict = Dict{String, Vector{Float64}}()
    for load in get_components(PowerLoad, system)
        load_name = get_name(load)
        active_power = get_active_power(load)
        # In our convention load forecasts are multiplicative, which means the forecast
        # multiplies the base value stored in the field `active_power`.
        ts_dict[load_name] =
            active_power .* get_time_series_values(SingleTimeSeries, load, "active_power")
    end
    return ts_dict
end

"""
    get_pmin(system::System) -> Dict

Returns Pmin, i.e., the minimum power outputs of the generators in `system`.
"""
get_pmin(system::System) = get_generator_time_series(system, "active_power_min")

"""
    get_pmax(system::System) -> Dict

Returns Pmax, i.e., the maximum power outputs of the generators in `system`.
"""
get_pmax(system::System) = get_generator_time_series(system, "active_power_max")

"""
    get_regmin(system::System) -> Dict

Returns the minimum power outputs with regulation of the generators in `system`.
"""
get_regmin(system::System) = get_generator_time_series(system, "regulation_min")

"""
    get_regmax(system::System) -> Dict

Returns the maximum power outputs with regulation of the generators in `system`.
"""
get_regmax(system::System) = get_generator_time_series(system, "regulation_max")

"""
    get_regulation_cost(system::System) -> Dict

Returns the costs of regulation offered by the generators in `system`.
"""
function get_regulation_cost(system::System)
    return get_generator_time_series(system, "regulation"; suffix=true)
end

"""
    get_commitment_status(system::System) -> Dict

Returns the commitment status of the Thermal generators in `system`.
"""
function get_commitment_status(system::System)
    return get_generator_time_series(system, "status"; suffix=false)
end

"""
    get_spinning_cost(system::System) -> Dict

Returns the costs of spinning reserve offered by the generators in `system`.
"""
function get_spinning_cost(system::System)
    return get_generator_time_series(system, "spinning"; suffix=true)
end

"""
    get_on_sup_cost(system::System) -> Dict

Returns the costs of online supplemental reserve offered by the generators in `system`.
"""
function get_on_sup_cost(system::System)
    return get_generator_time_series(system, "supplemental_on"; suffix=true)
end

"""
    get_off_sup_cost(system::System) -> Dict

Returns the costs of offline supplemental reserve offered by the generators in `system`.
"""
function get_off_sup_cost(system::System)
    return get_generator_time_series(system, "supplemental_off"; suffix=true)
end

"""
    get_offer_curves(system::System) -> Dict

Returns the offer curves of generators in `system`.
"""
get_offer_curves(system::System) = get_generator_time_series(system, "offer_curve")

"""
    get_noload_cost(system::System) -> Dict

Returns the no-load costs of the generators in `system`.
"""
get_noload_cost(system::System) = get_generator_time_series(system, "no_load_cost")

"""
    get_startup_cost(system::System) -> Dict

Returns the start-up costs of the generators in `system`.
"""
get_startup_cost(system::System) = get_generator_time_series(system, "start_up_cost")

"""
    get_reserve_zones(system::System) -> Vector{Int}

Returns a vector with the reserve zone numbers in `system`. The market-wide zone is defined
as $(MARKET_WIDE_ZONE) in accordance with FullNetworkDataPrep.jl.
"""
function get_reserve_zones(system::System)
    reserve_zones = map(get_components(Service, system)) do serv
        serv.ext["reserve_zone"]
    end
    return unique(reserve_zones)
end

"""
    get_regulation_requirements(system::System) -> Dict

Returns the zonal and market-wide regulation requirements in `system`. The keys of the
dictionary represent the reserve zones and the values represent the requirements.
"""
function get_regulation_requirements(system::System)
    services = collect(get_components(Service, system))
    filter!(x -> x.ext["label"] == :reg, services)
    reg_reqs = Dict{Int, Float64}()
    for reg in services
        reg_reqs[reg.ext["reserve_zone"]] = reg.requirement
    end
    return reg_reqs
end

"""
    get_operating_reserve_requirements(system::System) -> Dict

Returns the zonal and market-wide operating reserve requirements in `system`. The keys of
the dictionary represent the reserve zones and the values represent the requirements.
"""
function get_operating_reserve_requirements(system::System)
    group_reserves = collect(get_components(StaticReserveGroup, system))
    or_reqs = Dict{Int, Float64}()
    for rsrv in group_reserves
        or_reqs[rsrv.ext["reserve_zone"]] = rsrv.requirement
    end
    return or_reqs
end

"""
    get_initial_generation(system::System) -> Dict

Returns the initial generation the units in `system`.
"""
get_initial_generation(system::System) = _generator_dict(get_active_power, system)

"""
    get_initial_commitment(system::System) -> Dict

Returns the initial commitment status the units in `system`.
"""
get_initial_commitment(system::System) = _generator_dict(x -> Int(get_status(x)), system)

"""
    get_minimum_uptime(system::System) -> Dict

Returns the minimum up-time of the units in `system`.
"""
function get_minimum_uptime(system::System)
    return _generator_dict(system) do gen
        get_time_limits(gen).up
    end
end

"""
    get_minimum_downtime(system::System) -> Dict

Returns the minimum down-time of the units in `system`.
"""
function get_minimum_downtime(system::System)
    return _generator_dict(system) do gen
        get_time_limits(gen).down
    end
end

"""
    get_initial_uptime(system::System) -> Dict

Returns the number of hours that each generator was online in the initial moment.
"""
function get_initial_uptime(system::System)
    time_at_status = _generator_dict(get_time_at_status, system)
    initial_commitment = get_initial_commitment(system)
    # Those that were offline have uptime of zero
    for (g, u) in initial_commitment
        if u == 0
            time_at_status[g] = 0.0
        end
    end
    return time_at_status
end

"""
    get_initial_downtime(system::System) -> Dict

Returns the number of hours that each generator was offline in the initial moment.
"""
function get_initial_downtime(system::System)
    time_at_status = _generator_dict(get_time_at_status, system)
    initial_commitment = get_initial_commitment(system)
    # Those that were online have downtime of zero
    for (g, u) in initial_commitment
        if u == 1
            time_at_status[g] = 0.0
        end
    end
    return time_at_status
end

"""
    get_regulation_providers(system::System) -> Vector{Int}

Returns the unit codes of the units that provide regulation.
"""
function get_regulation_providers(system::System)
    return _get_service_providers(system, "regulation_$MARKET_WIDE_ZONE")
end

"""
    get_spinning_providers(system::System) -> Vector{Int}

Returns the unit codes of the units that provide spinning reserve.
"""
function get_spinning_providers(system::System)
    return _get_service_providers(system, "spinning_$MARKET_WIDE_ZONE")
end

"""
    get_on_sup_providers(system::System) -> Vector{Int}

Returns the unit codes of the units that provide online supplemental reserve.
"""
function get_on_sup_providers(system::System)
    return _get_service_providers(system, "supplemental_on_$MARKET_WIDE_ZONE")
end

"""
    get_off_sup_providers(system::System) -> Vector{Int}

Returns the unit codes of the units that provide offline supplemental reserve.
"""
function get_off_sup_providers(system::System)
    return _get_service_providers(system, "supplemental_off_$MARKET_WIDE_ZONE")
end

"""
    get_ramp_rates(system::System) -> Dict

Returns a dictionary with the ramp rates in pu/min of each unit in `system`.
"""
function get_ramp_rates(system::System)
    return _generator_dict(system) do gen
        get_ramp_limits(gen).up
    end
end

"""
    get_startup_limits(system::System) -> Dict

Returns a dictionary with the start-up limits of each unit in `system`. The start-up limits
are defined as equal to Regmin to avoid infeasibilities. Since we don't
currently differentiate between ramp up and down, this can also be used to obtain the
shutdown limits, which are identical under this assumption.
"""
get_startup_limits(system::System) = get_regmin(system)
