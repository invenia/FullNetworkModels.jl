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
    unit_codes = keys(get_generators(system))
    Pmax = get_pmax(system)
    feasibility *= _total_demand_feasibility(system, unit_codes, Pmax)
    feasibility *= _initial_ramp_feasibility(system, unit_codes, Pmax)
    feasibility *= _ancillary_requirement_feasibility(system)
    return feasibility
end

"""
    _total_demand_feasibility(system, unit_codes, Pmax) -> Bool

Verifies that the system is able to attend its demand in each hour by looking at the
system-wide generation capacity.
"""
function _total_demand_feasibility(system, unit_codes, Pmax)
    loads = get_load(system)
    load_names = axiskeys(loads, 1)
    datetimes = get_datetimes(system)
    n_periods = length(datetimes)
    gen_capacity = Vector{Float64}(undef, n_periods)
    system_load = Vector{Float64}(undef, n_periods)
    infeasible_periods = DateTime[]
    for (i, t) in enumerate(datetimes)
        gen_capacity[i] = sum(Pmax(g, t) for g in unit_codes)
        system_load[i] = sum(loads(l, t) for l in load_names)
        if gen_capacity[i] < system_load[i]
            push!(infeasible_periods, t)
        end
    end
    if !isempty(infeasible_periods)
        str = "There's not enough generation to meet the system-wide demand; problem will be infeasible."
        for (i, t) in enumerate(datetimes)
            str *= "\n Time period: $t | Generation capacity: $(gen_capacity[i]) | System load: $(system_load[i])"
        end
        warn(LOGGER, str)
        return false
    end
    return true
end

"""
    _initial_ramp_feasibility(system, unit_codes, datetimes, Pmax) -> Bool

Verifies if the units that are initially online are able to go from their generation at t=0
to a value within [Pmin, Pmax] at t=1. For example, in a problem with hourly resolution, if
the generation at t=0 is 200 MW, the Pmax at t=1 is 100 MW, and the ramp rate is 1 MW/min,
then there is not enough ramping capability for the generator to ramp down to its maximum
allowed output at t=1.
"""
function _initial_ramp_feasibility(system, unit_codes, Pmax)
    U0 = get_initial_commitment(system)
    P0 = get_initial_generation(system)
    Pmin = get_pmin(system)
    generators = get_generators(system)
    datetimes = get_datetimes(system)
    Δt = Dates.value(Minute(first(diff(datetimes))))
    h1 = first(datetimes)
    for g in unit_codes
        if U0(g) == 1
            if P0(g) > Pmax(g, h1) + Δt * generators[g].ramp_up || P0(g) < Pmin(g, h1) - Δt * generators[g].ramp_up
                warn(LOGGER, "Initial ramp constraints are being violated. Problem will be infeasible if hard constraints for ramps are used.")
                return false
            end
        end
    end
    return true
end

"""
    _ancillary_requirement_feasibility(system) -> Bool

Verifies if there is enough capacity to attend ancillary service requirements in each zone
(including market-wide). Note that the total regmax is used to run the operating reserve
checks – for units that are not providing regulation, Pmax should be used, but this can't
be known beforehand. Nonetheless, this is a bound that has virtually zero probability of
being exceeded by the requirements unless there is some data issue.
"""
function _ancillary_requirement_feasibility(system)
    regmax = get_regmax(system)
    zone_gens = gens_per_zone(system)
    reg_reqs = get_regulation_requirements(system)
    or_reqs = get_operating_reserve_requirements(system)
    reg_pairs = _provider_indices(get_regulation(system))
    spin_pairs = _provider_indices(get_spinning(system))
    sup_on_pairs = _provider_indices(get_supplemental_on(system))
    sup_off_pairs = _provider_indices(get_supplemental_off(system))
    or_pairs = union(
        reg_pairs, spin_pairs, sup_on_pairs, sup_off_pairs
    )
    datetimes = get_datetimes(system)
    for t in datetimes, zone in keys(get_zones(system))
        # Get the units providing regulation within that zone
        reg_zone_units = reg_pairs[[in(unit, zone_gens[zone]) for unit in first.(reg_pairs)]]
        total_regmax = sum(regmax(g, t) for (g, t) in reg_zone_units)
        if total_regmax < reg_reqs[zone]
            warn(LOGGER, "There's not enough regulation to attend zonal regulation requirements; problem will be infeasible.")
            return false
        end
        # Get the units providing OR services within that zone
        or_zone_units = or_pairs[[in(unit, zone_gens[zone]) for unit in first.(or_pairs)]]
        total_regmax = sum(regmax(g, t) for (g, T) in or_zone_units)
        if total_regmax < or_reqs[zone]
            warn(LOGGER, "There's not enough regulation to attend zonal operating reserve requirements; problem will be infeasible.")
            return false
        end
    end
    return true
end
