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
    get_forecast_timestamps(system::System) -> Vector{DateTime}

Returns a vector with all forecast timestamps stored in `system`.
"""
function get_forecast_timestamps(system::System)
    initial_timestamp = get_forecast_initial_timestamp(system)
    horizon = get_forecast_horizon(system)
    interval = get_forecast_interval(system)
    return map(0:(horizon - 1)) do t
        initial_timestamp + t * interval
    end::Vector{DateTime}
end

# Extra constructor for convenience
function FullNetworkModel{T}(system::System, solver) where T<:UCED
    datetimes = get_forecast_timestamps(system)
    return FullNetworkModel{T}(Model(solver), system, datetimes)
end

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
    return map(get_name, get_components(bidtype, system))
end

"""
    get_load_names(loadtype::Type{<:StaticLoad}, system::System) -> Vector{String}

Returns the names of all loads in `system` under type `loadtype`.
"""
function get_load_names(loadtype::Type{<:StaticLoad}, system::System)
    return get_name.(get_components(loadtype, system))
end

"""
    get_generator_time_series(
        system::System,
        label::AbstractString,
        datetimes::Vector{DateTime}=get_forecast_timestamps(system);
        suffix=false
    ) -> DenseAxisArray

Returns a DenseAxisArray with the time series values for `label` stored in `system` for the
periods in `datetimes`. If the label is supposed to have a zone suffix, e.g. ancillary
costs, then `suffix` should be set to `true`. The axes of the array are the unit codes and
the datetimes, respectively.
"""
function get_generator_time_series(
    system::System,
    label::AbstractString,
    datetimes::Vector{DateTime}=get_forecast_timestamps(system);
    suffix=false
)
    gens = get_components(ThermalGen, system)
    # If it's a zonal service, get only the providers; otherwise get all generators
    unit_codes = if suffix
        _get_service_providers(system, label * "_$MARKET_WIDE_ZONE")
    else
        parse.(Int, get_name.(gens))
    end
    time_series_values = _generator_time_series_values.(gens, label, Ref(datetimes), suffix)
    # Filter out the nothings resulting from generators that don't have the time series
    filter!(!isnothing, time_series_values)
    # `permutedims` because our convention is that datetimes are the last dimension
    output = DenseAxisArray(
        permutedims(reduce(hcat, time_series_values)), unit_codes, datetimes
    )
    return output
end

"""
    get_fixed_loads(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns a DenseAxisArray with the fixed load forecasts stored in `system` for the periods in
`datetimes`. The axes of the array are the load names and the datetimes, respectively.
"""
function get_fixed_loads(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    loads = get_components(PowerLoad, system)
    load_names = get_load_names(PowerLoad, system)
    time_series_values = _load_time_series_values.(loads, Ref(datetimes))
    output = DenseAxisArray(
        permutedims(reduce(hcat, time_series_values)), load_names, datetimes
    )
    return output
end

"""
    get_pmin(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns Pmin, i.e., the minimum power outputs of the generators in `system` for the
periods in `datetimes`.
"""
function get_pmin(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "active_power_min", datetimes)
end

"""
    get_pmax(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns Pmax, i.e., the maximum power outputs of the generators in `system` for the
periods in `datetimes`.
"""
function get_pmax(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "active_power_max", datetimes)
end

"""
    get_regmin(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the minimum power outputs with regulation of the generators in `system` for the
periods in `datetimes`.
"""
function get_regmin(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "regulation_min", datetimes)
end

"""
    get_regmax(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the maximum power outputs with regulation of the generators in `system` for the
periods in `datetimes`.
"""
function get_regmax(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "regulation_max", datetimes)
end

"""
    get_regulation_cost(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the costs of regulation offered by the generators in `system` for the periods
in `datetimes`.
"""
function get_regulation_cost(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "regulation", datetimes; suffix=true)
end

"""
    get_commitment_status(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the commitment status of the Thermal generators in `system` for the periods in
`datetimes`.
"""
function get_commitment_status(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "status", datetimes)
end

"""
    get_commitment_reg_status(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the commitment regulation status of the Thermal generators in `system` for the
periods in `datetimes`.
"""
function get_commitment_reg_status(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "status_reg", datetimes)
end

"""
    get_spinning_cost(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the costs of spinning reserve offered by the generators in `system` for the periods
in `datetimes`.
"""
function get_spinning_cost(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "spinning", datetimes; suffix=true)
end

"""
    get_on_sup_cost(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the costs of online supplemental reserve offered by the generators in `system` for
the periods in `datetimes`.
"""
function get_on_sup_cost(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "supplemental_on", datetimes; suffix=true)
end

"""
    get_off_sup_cost(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the costs of offline supplemental reserve offered by the generators in `system` for
the periods in `datetimes`.
"""
function get_off_sup_cost(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "supplemental_off", datetimes; suffix=true)
end

"""
    get_offer_curves(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the offer curves of generators in `system` for the periods in `datetimes`.
"""
function get_offer_curves(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "offer_curve", datetimes)
end

"""
    get_noload_cost(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the no-load costs of the generators in `system` for the periods in `datetimes`.
"""
function get_noload_cost(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "no_load_cost", datetimes)
end

"""
    get_startup_cost(
        system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns the start-up costs of the generators in `system` for the periods in `datetimes`.
"""
function get_startup_cost(
    system::System, datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    return get_generator_time_series(system, "start_up_cost", datetimes)
end

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

"""
    get_bid_curves(
        bidtype::Type{<:Device},
        system::System,
        datetimes::Vector{DateTime}=get_forecast_timestamps(system)
    ) -> DenseAxisArray

Returns a DenseAxisArray with the bid curves time series stored in `system` for devices of
type `bidtype` for the periods in `datetimes`. The axes of the array are the unit codes and
the datetimes, respectively.
"""
function get_bid_curves(
    bidtype::Type{<:Device},
    system::System,
    datetimes::Vector{DateTime}=get_forecast_timestamps(system)
)
    bids = get_components(bidtype, system)
    bid_names = get_bid_names(bidtype, system)
    time_series_values = _time_series_values.(bids, "bid_curve", Ref(datetimes))
    output = DenseAxisArray(
        permutedims(reduce(hcat, time_series_values)), bid_names, datetimes
    )
    return output
end
