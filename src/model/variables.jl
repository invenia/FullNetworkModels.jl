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

function _add_ancillary_services_latex()
    return """
        ``r^{\\text{reg}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{on-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    add_ancillary_services!(
        fnm::FullNetworkModel; reg=true, spin=true, on_sup=true, off_sup=true
    )

Adds the ancillary service variables indexed, respectively, by the unit codes of the thermal
generators in `system` and by the time periods considered. The variables include regulation,
regulation commitment, spinning, online supplemental, and offline supplemental reserves.

$(_add_ancillary_services_latex())

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
