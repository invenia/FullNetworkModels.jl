function _add_thermal_generation_latex()
    return """
    ``p_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    add_thermal_generation!(fnm::FullNetworkModel)

Adds the thermal generation variables `p` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered:

$(_add_thermal_generation_latex())
"""
function add_thermal_generation!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    @variable(fnm.model, p[g in unit_codes, t in 1:n_periods] >= 0)
    return fnm
end

function _add_commitment_latex()
    return """
    ``u_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    add_commitment!(fnm::FullNetworkModel)

Adds the binary commitment variables `u` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered:

$(_add_commitment_latex())
"""
function add_commitment!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    @variable(fnm.model, u[g in unit_codes, t in 1:n_periods], Bin)
    return fnm
end

function _add_startup_shutdown_variables_latex()
    return """
        ``0 \\leq v_{g, t} \\leq 1, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``0 \\leq w_{g, t} \\leq 1, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function _add_startup_shutdown_constraints_latex()
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

$(_add_startup_shutdown_variables_latex())
$(_add_startup_shutdown_constraints_latex())
"""
function add_startup_shutdown!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "u")
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    # Get variables and parameters for better readability
    u = model[:u]
    U0 = get_initial_commitment(system)
    @variable(model, 0 <= v[g in unit_codes, t in 1:n_periods] <= 1)
    @variable(model, 0 <= w[g in unit_codes, t in 1:n_periods] <= 1)
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
    return fnm
end

function _add_ancillary_services_variables_latex()
    return """
        ``r^{\\text{reg}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``u^{\\text{reg}}_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{on-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function _add_ancillary_services_constraints_latex()
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

$(_add_ancillary_services_variables_latex())
$(_add_ancillary_services_constraints_latex())

The created variables are named `r_reg`, `u_reg`, `r_spin`, `r_on_sup`, and `r_off_sup`.
"""
function add_ancillary_services!(fnm::FullNetworkModel)
    model = fnm.model
    @assert has_variable(model, "u")
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    u = model[:u]
    @variable(model, r_reg[g in unit_codes, t in 1:n_periods] >= 0)
    @variable(model, u_reg[g in unit_codes, t in 1:n_periods], Bin)
    # We add a constraint here because it is part of the basic definition of `u_reg`
    @constraint(model, [g in unit_codes, t in 1:n_periods], u_reg[g, t] <= u[g, t])
    @variable(model, r_spin[g in unit_codes, t in 1:n_periods] >= 0)
    @variable(model, r_on_sup[g in unit_codes, t in 1:n_periods] >= 0)
    @variable(model, r_off_sup[g in unit_codes, t in 1:n_periods] >= 0)
    return fnm
end
