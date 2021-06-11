"""
    basic_feasibility_checks(system::System) -> Bool

Inspects the system data to run some basic checks on the feasibility of the problem.
This is done on the system rather than the actual JuMP problem because building the problem
is time-consuming for large systems, so it's useful to have these checks beforehand.
Throws a warning for each class of constraint that will cause infeasibilities, returning
`true` if no infeasibilities were detected and `false` if any infeasibilities were detected.
Note that this does not guarantee that the problem will be feasible; it just runs basic
sanity checks to catch simple data issues.
"""
function basic_feasibility_checks(system::System)
    feasibility = true
    unit_codes = get_unit_codes(ThermalGen, system)
    Pmax = get_pmax(system)
    n_periods = get_forecast_horizon(system)
    feasibility *= _initial_ramp_feasibility(system, unit_codes, Pmax)
    feasibility *= _ancillary_requirement_feasibility(system, n_periods)
    return feasibility
end

"""
    _initial_ramp_feasibility(system, unit_codes, Pmax) -> Bool

Verifies if the units that are initially online are able to go from their generation at t=0
to a value within [Pmin, Pmax] at t=1. For example, if the generation at t=0 is 200 MW, the
Pmax at t=1 is 100 MW, and the ramp rate is 1 MW/min, then there is not enough ramping
capability for the generator to ramp down to its maximum allowed output at t=1.
"""
function _initial_ramp_feasibility(system, unit_codes, Pmax)
    U0 = get_initial_commitment(system)
    P0 = get_initial_generation(system)
    Pmin = get_pmin(system)
    RR = get_ramp_rates(system)
    SU = get_startup_limits(system)
    Δt = _get_resolution_in_minutes(system)
    for g in unit_codes
        if U0[g] == 1
            if P0[g] > Pmax[g][1] + Δt * RR[g] || P0[g] < Pmin[g][1] - Δt * RR[g]
                warn(LOGGER, "Initial ramp constraints are being violated. Problem will be infeasible if hard constraints for ramps are used.")
                return false
            end
        end
    end
    return true
end

"""
    _total_demand_feasibility()

Verifies that the system is able to attend its demand in each hour by looking at the
system-wide generation capacity.
"""
function _total_demand_feasibility(system)
    loads = get_fixed_loads(system)
end

"""
    _ancillary_requirement_feasibility(system, n_periods) -> Bool

Verifies if there is enough capacity to attend ancillary service requirements in each zone
(including market-wide). Note that the total regmax is used to run the operating reserve
checks – for units that are not providing regulation, Pmax should be used, but this can't
be known beforehand. Nonetheless, this is a bound that has virtually zero probability of
being exceeded by the requirements unless there is some data issue.
"""
function _ancillary_requirement_feasibility(system, n_periods)
    regmax = get_regmax(system)
    zone_gens = _generators_by_reserve_zone(system)
    reg_reqs = get_regulation_requirements(system)
    or_reqs = get_operating_reserve_requirements(system)
    reg_units = get_regulation_providers(system)
    or_units = union(
        reg_units,
        get_spinning_providers(system),
        get_on_sup_providers(system),
        get_off_sup_providers(system),
    )
    for t in 1:n_periods, zone in get_reserve_zones(system)
        # Get the units providing regulation within that zone
        reg_zone_units = intersect(zone_gens[zone], reg_units)
        total_regmax = sum(regmax[g][1] for g in reg_zone_units)
        if total_regmax < reg_reqs[zone]
            warn(LOGGER, "There's not enough regulation to attend zonal regulation requirements; problem will be infeasible.")
            return false
        end
        # Get the units providing OR services within that zone
        or_zone_units = intersect(zone_gens[zone], or_units)
        total_regmax = sum(regmax[g][1] for g in or_zone_units)
        if total_regmax < or_reqs[zone]
            warn(LOGGER, "There's not enough regulation to attend zonal operating reserve requirements; problem will be infeasible.")
            return false
        end
    end
    return true
end
