function _add_thermal_generation()
    return """
    ``p_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    add_thermal_generation!(fnm::FullNetworkModel)

Adds the thermal generation variables `p` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered.

$(_add_thermal_generation())

where ``\\mathcal{T}`` is the set of time periods defined in the forecasts in `system`.
"""
function add_thermal_generation!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    @variable(fnm.model, p[g in unit_codes, t in 1:n_periods] >= 0)
    return fnm
end

function _add_commitment()
    return """
    ``u_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    add_commitment!(fnm::FullNetworkModel)

Adds the binary commitment variables `u` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered.

$(_add_commitment())

where ``\\mathcal{T}`` is the set of time periods defined in the forecasts in `system`.
"""
function add_commitment!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    @variable(fnm.model, u[g in unit_codes, t in 1:n_periods], Bin)
    return fnm
end
