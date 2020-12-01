function _generation_limits_latex(; commitment::Bool)
    u_gt = commitment ? "u_{g, t}" : ""
    return """
        ``P^{\\min}_{g, t} $u_gt \\leq p_{g, t} \\leq P^{\\max}_{g, t} $u_gt, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    generation_limits!(fnm::FullNetworkModel)

Adds generation limit constraints to the full network model:

$(_generation_limits_latex(commitment=true))

if `fnm.model` has commitment, or

$(_generation_limits_latex(commitment=false))

if `fnm.model` does not have commitment.

The constraints added are named `generation_min` and `generation_max`.
"""
function generation_limits!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "p")
    _generation_limits!(
        model,
        Val(has_variable(model, "u")),
        get_unit_codes(ThermalGen, system),
        get_forecasts_horizon(system),
        get_pmin(system),
        get_pmax(system),
    )
    return fnm
end

function _ancillary_service_limits_latex()
    return """
        ``p_{g, t} + r^{\\text{reg}}_{g, t} + r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} \\leq P^{\\max}_{g, t} (u_{g, t} - u^{\\text{reg}}_{g, t}) + P^{\\text{reg-max}}_{g, t} u^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``p_{g, t} - r^{\\text{reg}}_{g, t} \\geq P^{\\min}_{g, t} (u_{g, t} - u^{\\text{reg}}_{g, t}) + P^{\\text{reg-min}}_{g, t} u^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{reg}}_{g, t} \\leq 0.5 (P^{\\text{reg-max}}_{g, t} - P^{\\text{reg-min}}_{g, t}) u^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} \\leq (P^{\\max}_{g, t} - P^{\\min}_{g, t}) u_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\leq (P^{\\max}_{g, t} - P^{\\min}_{g, t}) (1 - u_{g, t}), \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    ancillary_service_limits!(fnm::FullNetworkModel)

Adds the constraints related to ancillary service limits to the full network model:

$(_ancillary_service_limits_latex())

The constraints added are named, respectively, `ancillary_max`, `ancillary_min`,
`regulation_max`, `spin_and_sup_max`, and `off_sup_max`.
"""
function ancillary_service_limits!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "p")
    @assert has_variable(model, "u")
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    Pmax = get_pmax(system)
    Pregmax = get_regmax(system)
    # Upper bound on generation + ancillary services
    _ancillary_max!(model, unit_codes, n_periods, Pmax, Pregmax)
    Pmin = get_pmin(system)
    Pregmin = get_regmin(system)
    # Lower bound on generation - ancillary services
    _ancillary_min!(model, unit_codes, n_periods, Pmin, Pregmin)
    # Upper bound on regulation
    _regulation_max!(model, unit_codes, n_periods, Pregmin, Pregmax)
    # Upper bound on spinning + online supplemental reserves
    _spin_and_sup_max!(model, unit_codes, n_periods, Pmin, Pmax)
    # Upper bound on offline supplemental reserve
    _off_sup_max!(model, unit_codes, n_periods, Pmin, Pmax)
    # Ensure that units that don't provide services have services set to zero
    _zero_non_providers!(model, system, unit_codes, n_periods)
    return fnm
end

function _regulation_requirements_latex()
    return """
        ``\\sum_{g \\in \\mathcal{G}_{z}} r^{\\text{reg}}_{g, t} \\geq R^{\\text{reg-req}}_{z}, \\forall z \\in \\mathcal{Z}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    regulation_requirements!(fnm::FullNetworkModel)

Adds zonal and market-wide regulation requirements to the full network model:

$(_regulation_requirements_latex())
"""
function regulation_requirements!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    reserve_zones = get_reserve_zones(system)
    zone_gens = _generators_by_reserve_zone(system)
    reg_requirements = get_regulation_requirements(system)
    # Get variable for better readability
    r_reg = model[:r_reg]
    @constraint(
        model,
        regulation_requirements[z in reserve_zones, t in 1:n_periods],
        sum(r_reg[g, t] for g in zone_gens[z]) >= reg_requirements[z]
    )
    return fnm
end

function _operating_reserve_requirements_latex()
    return """
        ``\\sum_{g \\in \\mathcal{G}_{z}} (r^{\\text{reg}}_{g, t} + r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} + r^{\\text{off-sup}}_{g, t}) \\geq R^{\\text{OR-req}}_{z}, \\forall z \\in \\mathcal{Z}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    operating_reserve_requirements!(fnm::FullNetworkModel)

Adds zonal and market-wide operating reserve requirements to the full network model:

$(_operating_reserve_requirements_latex())
"""
function operating_reserve_requirements!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    reserve_zones = get_reserve_zones(system)
    zone_gens = _generators_by_reserve_zone(system)
    or_requirements = get_operating_reserve_requirements(system)
    # Get variables for better readability
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    @constraint(
        model,
        operating_reserve_requirements[z in reserve_zones, t in 1:n_periods],
        sum(
            r_reg[g, t] + r_spin[g, t] + r_on_sup[g, t] + r_off_sup[g, t]
                for g in zone_gens[z]
        ) >= or_requirements[z]
    )
    return fnm
end

function _energy_balance_latex()
    return """
        ``\\sum_{g \\in \\mathcal{G}} p_{g, t} = \\sum_{f \\in \\mathcal{F}} D_{f, t}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    energy_balance!(fnm::FullNetworkModel)

Adds the energy balance constraints to the full network model. The constraints ensure that
the total generation in the system meets the demand in each time period, assuming no loss:

$(_energy_balance_latex())
"""
function energy_balance!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    unit_codes = get_unit_codes(ThermalGen, system)
    load_names = get_load_names(PowerLoad, system)
    n_periods = get_forecasts_horizon(system)
    D = get_fixed_loads(system)
    # Get variables for better readability
    p = model[:p]
    @constraint(
        model,
        energy_balance[t in 1:n_periods],
        sum(p[g, t] for g in unit_codes) == sum(D[f][t] for f in load_names)
    )
    return fnm
end

function _generation_limits!(model::Model, ::Val{true}, unit_codes, n_periods, Pmin, Pmax)
    p = model[:p]
    u = model[:u]
    @constraint(
        model,
        generation_min[g in unit_codes, t in 1:n_periods],
        Pmin[g][t] * u[g, t] <= p[g, t]
    )
    @constraint(
        model,
        generation_max[g in unit_codes, t in 1:n_periods],
        p[g, t] <= Pmax[g][t] * u[g, t]
    )
    return model
end

function _generation_limits!(model::Model, ::Val{false}, unit_codes, n_periods, Pmin, Pmax)
    p = model[:p]
    @constraint(
        model,
        generation_min[g in unit_codes, t in 1:n_periods],
        Pmin[g][t] <= p[g, t]
    )
    @constraint(
        model,
        generation_max[g in unit_codes, t in 1:n_periods],
        p[g, t] <= Pmax[g][t]
    )
end

function _ancillary_max!(model::Model, unit_codes, n_periods, Pmax, Pregmax)
    # Get variables for better readability
    p = model[:p]
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    u = model[:u]
    u_reg = model[:u_reg]
    @constraint(
        model,
        ancillary_max[g in unit_codes, t in 1:n_periods],
        p[g, t] + r_reg[g, t] + r_spin[g, t] + r_on_sup[g, t] <=
            Pmax[g][t] * (u[g, t] - u_reg[g, t]) + Pregmax[g][t] * u_reg[g, t]
    )
    return model
end

function _ancillary_min!(model::Model, unit_codes, n_periods, Pmin, Pregmin)
    # Get variables for better readability
    p = model[:p]
    r_reg = model[:r_reg]
    u = model[:u]
    u_reg = model[:u_reg]
    @constraint(
        model,
        ancillary_min[g in unit_codes, t in 1:n_periods],
        p[g, t] - r_reg[g, t] >=
            Pmin[g][t] * (u[g, t] - u_reg[g, t]) + Pregmin[g][t] * u_reg[g, t]
    )
    return model
end

function _regulation_max!(model::Model, unit_codes, n_periods, Pregmin, Pregmax)
    # Get variable for better readability
    r_reg = model[:r_reg]
    u_reg = model[:u_reg]
    @constraint(
        model,
        regulation_max[g in unit_codes, t in 1:n_periods],
        r_reg[g, t] <= 0.5 * (Pregmax[g][t] - Pregmin[g][t]) * u_reg[g, t]
    )
    return model
end

function _spin_and_sup_max!(model::Model, unit_codes, n_periods, Pmin, Pmax)
    # Get variables for better readability
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    u = model[:u]
    @constraint(
        model,
        spin_and_sup_max[g in unit_codes, t in 1:n_periods],
        r_spin[g, t] + r_on_sup[g, t] <= (Pmax[g][t] - Pmin[g][t]) * u[g, t]
    )
    return model
end

function _off_sup_max!(model::Model, unit_codes, n_periods, Pmin, Pmax)
    # Get variables for better readability
    r_off_sup = model[:r_off_sup]
    u = model[:u]
    @constraint(
        model,
        off_sup_max[g in unit_codes, t in 1:n_periods],
        r_off_sup[g, t] <= (Pmax[g][t] - Pmin[g][t]) * (1 - u[g, t])
    )
    return model
end

function _zero_non_providers!(model::Model, system::System, unit_codes, n_periods)
    # Units that provide each service
    reg_providers = get_regulation_providers(system)
    spin_providers = get_spinning_providers(system)
    on_sup_providers = get_on_sup_providers(system)
    off_sup_providers = get_off_sup_providers(system)
    # Get variables for better readability
    r_reg = model[:r_reg]
    u_reg = model[:u_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    @constraint(
        model,
        zero_reg[g in setdiff(unit_codes, reg_providers), t in 1:n_periods],
        r_reg[g, t] == 0
    )
    @constraint(
        model,
        zero_u_reg[g in setdiff(unit_codes, reg_providers), t in 1:n_periods],
        u_reg[g, t] == 0
    )
    @constraint(
        model,
        zero_spin[g in setdiff(unit_codes, spin_providers), t in 1:n_periods],
        r_spin[g, t] == 0
    )
    @constraint(
        model,
        zero_on_sup[g in setdiff(unit_codes, on_sup_providers), t in 1:n_periods],
        r_on_sup[g, t] == 0
    )
    @constraint(
        model,
        zero_off_sup[g in setdiff(unit_codes, off_sup_providers), t in 1:n_periods],
        r_off_sup[g, t] == 0
    )
    return model
end
