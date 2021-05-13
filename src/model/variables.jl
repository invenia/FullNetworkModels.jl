# Define functions so that `_latex` can be dispatched over them
function add_thermal_generation! end
function add_commitment! end
function _add_startup_shutdown_variables! end
function _add_startup_shutdown_constraints! end
function _add_ancillary_services_variables! end
function _add_ancillary_services_constraints! end

function _latex(::typeof(add_thermal_generation!))
    return """
    ``p_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    add_thermal_generation!(fnm::FullNetworkModel)

Adds the thermal generation variables `p` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered:

$(_latex(add_thermal_generation!))
"""
function add_thermal_generation!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecast_horizon(fnm.system)
    @variable(fnm.model, p[g in unit_codes, t in 1:n_periods] >= 0)
    return fnm
end

function _latex(::typeof(add_commitment!))
    return """
    ``u_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    add_commitment!(fnm::FullNetworkModel)

Adds the binary commitment variables `u` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered:

$(_latex(add_commitment!))
"""
function add_commitment!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecast_horizon(fnm.system)
    @variable(fnm.model, u[g in unit_codes, t in 1:n_periods], Bin)
    return fnm
end

function _latex(::typeof(_add_startup_shutdown_variables!))
    return """
        ``0 \\leq v_{g, t} \\leq 1, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``0 \\leq w_{g, t} \\leq 1, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function _latex(::typeof(_add_startup_shutdown_constraints!))
    return """
        ``u_{g, t} - u_{g, t - 1} = v_{g, t} - w_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T} \\setminus \\{1\\}`` \n
        ``u_{g, 1} - U^{0}_{g} = v_{g, 1} - w_{g, 1}, \\forall g \\in \\mathcal{G}``
        """
end

"""
    add_startup_shutdown!(fnm::FullNetworkModel)

Adds the variables `v` and `w` representing the start-up and shutdown of generators,
respectively, indexed by the unit codes of the thermal generators in `system` and by the
time periods considered:

$(_latex(_add_startup_shutdown_constraints!))
$(_latex(_add_startup_shutdown_variables!))
"""
function add_startup_shutdown!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "u")
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecast_horizon(system)
    _add_startup_shutdown_variables!(model, unit_codes, n_periods)
    _add_startup_shutdown_constraints!(model, system, unit_codes, n_periods)
    return fnm
end

function _add_startup_shutdown_variables!(model::Model, unit_codes, n_periods)
    @variable(model, 0 <= v[g in unit_codes, t in 1:n_periods] <= 1)
    @variable(model, 0 <= w[g in unit_codes, t in 1:n_periods] <= 1)
    return model
end

function _add_startup_shutdown_constraints!(model::Model, system, unit_codes, n_periods)
    # Get variables and parameters for better readability
    u = model[:u]
    v = model[:v]
    w = model[:w]
    U0 = get_initial_commitment(system)
    # Add the constraints that model the start-up and shutdown variables
    @constraint(
        model,
        startup_shutdown_definition[g in unit_codes, t in 2:n_periods],
        u[g, t] - u[g, t - 1] == v[g, t] - w[g, t]
    )
    @constraint(
        model,
        startup_shutdown_definition_initial[g in unit_codes],
        u[g, 1] - U0[g] == v[g, 1] - w[g, 1]
    )
    return model
end

function _latex(::typeof(_add_ancillary_services_variables!))
    return """
        ``r^{\\text{reg}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``u^{\\text{reg}}_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{on-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function _latex(::typeof(_add_ancillary_services_constraints!))
    return """
        ``u^{\\text{reg}}_{g, t} \\leq u_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    add_ancillary_services!(
        fnm::FullNetworkModel; reg=true, spin=true, on_sup=true, off_sup=true
    )

Adds the ancillary service variables indexed, respectively, by the unit codes of the thermal
generators in `system` and by the time periods considered. The variables include regulation,
regulation commitment, spinning, online supplemental, and offline supplemental reserves.

$(_latex(_add_ancillary_services_constraints!))
$(_latex(_add_ancillary_services_variables!))

The created variables are named `r_reg`, `u_reg`, `r_spin`, `r_on_sup`, and `r_off_sup`.
"""
function add_ancillary_services!(fnm::FullNetworkModel)
    model = fnm.model
    @assert has_variable(model, "u")
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecast_horizon(fnm.system)
    _add_ancillary_services_variables!(model, unit_codes, n_periods)
    _add_ancillary_services_constraints!(model, unit_codes, n_periods)
    return fnm
end

function _add_ancillary_services_variables!(model::Model, unit_codes, n_periods)
    @variable(model, r_reg[g in unit_codes, t in 1:n_periods] >= 0)
    @variable(model, u_reg[g in unit_codes, t in 1:n_periods], Bin)
    @variable(model, r_spin[g in unit_codes, t in 1:n_periods] >= 0)
    @variable(model, r_on_sup[g in unit_codes, t in 1:n_periods] >= 0)
    @variable(model, r_off_sup[g in unit_codes, t in 1:n_periods] >= 0)
    return model
end

function _add_ancillary_services_constraints!(model::Model, unit_codes, n_periods)
    u = model[:u]
    u_reg = model[:u_reg]
    # We add a constraint here because it is part of the basic definition of `u_reg`
    @constraint(model, [g in unit_codes, t in 1:n_periods], u_reg[g, t] <= u[g, t])
    return model
end
