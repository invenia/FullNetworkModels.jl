function _thermal_variable_cost_objective_latex()
    return """
    ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} \\sum_{q \\in \\mathcal{Q}_{g, t}} p^{\\text{aux}}_{g, t, q} \\Lambda^{\\text{offer}}_{g, t, q}``
    """
end

function _thermal_variable_cost_constraints_latex(; commitment)
    u_gt = commitment ? "u_{g, t}" : ""
    return """
        ``0 \\leq p^{\\text{aux}}_{g, t, q} \\leq \\bar{P}_{g, t, q} $u_gt, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}, q \\in \\mathcal{Q}_{g, t}`` \n
        ``p_{g, t} = \\sum_{q \\in \\mathcal{Q}_{g, t}} p^{\\text{aux}}_{g, t, q}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    thermal_variable_cost!(fnm::FullNetworkModel)

Adds the variable cost related to thermal generators by using auxiliary generation variables
that multiply the offer prices. The variables `p_aux` are indexed, respectively, by the unit
codes of the thermal generators in `system`, by the time periods considered, and by the
offer block number.

Adds to the objective function:

$(_thermal_variable_cost_objective_latex())

And adds the following constraints:

$(_thermal_variable_cost_constraints_latex(commitment=true))

if `fnm.model` has commitment, or

$(_thermal_variable_cost_constraints_latex(commitment=false))

if `fnm.model` does not have commitment.
"""
function thermal_variable_cost!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "p")
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    offer_curves = get_offer_curves(system)
    # Get properties of the offer curves: prices, block MW limits, number of blocks
    Λ, p_aux_lims, n_blocks = _offer_curve_properties(offer_curves, n_periods)
    # Add variables and constraints for thermal generation blocks
    _add_thermal_gen_blocks!(model, unit_codes, p_aux_lims, n_periods, n_blocks)
    # Add thermal variable cost to objective
    _thermal_variable_cost_objective!(model, unit_codes, n_periods, n_blocks, Λ)
    return fnm
end

function _thermal_noload_cost_latex()
    return """
        ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} C^{\\text{nl}}_{g, t} u_{g, t}``
        """
end

"""
    thermal_noload_cost!(fnm::FullNetworkModel)

Adds the no-load cost of thermal generators to the model formulation:

$(_thermal_noload_cost_latex())
"""
thermal_noload_cost!(fnm::FullNetworkModel) = _thermal_linear_cost!(
    fnm, :u, get_noload_cost
)

function _thermal_startup_cost_latex()
    return """
        ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} C^{\\text{st}}_{g, t} v_{g, t}``
        """
end

"""
    thermal_startup_cost!(fnm::FullNetworkModel)

Adds the start-up cost of thermal generators to the model formulation:

$(_thermal_startup_cost_latex())
"""
thermal_startup_cost!(fnm::FullNetworkModel) = _thermal_linear_cost!(
    fnm, :v, get_startup_cost
)

function _ancillary_service_costs_latex()
    return """
        ``\\sum_{g \\in \\mathcal{G}} \\sum_{t \\in \\mathcal{T}} (C^{\\text{reg}}_{g, t} r^{\\text{reg}}_{g, t} + C^{\\text{spin}}_{g, t} r^{\\text{spin}}_{g, t} + C^{\\text{on-sup}}_{g, t} r^{\\text{on-sup}}_{g, t} + C^{\\text{off-sup}}_{g, t} r^{\\text{off-sup}}_{g, t})``
        """
end

"""
    ancillary_service_costs!(fnm::FullNetworkModel)

Adds the ancillary service costs related to thermal generators, namely regulation, spinning,
online supplemental, and offline supplemental reserves.

Adds to the objective function:

$(_ancillary_service_costs_latex())
"""
function ancillary_service_costs!(fnm::FullNetworkModel)
    _thermal_linear_cost!(fnm, :r_reg, get_regulation_cost)
    _thermal_linear_cost!(fnm, :r_spin, get_spinning_cost)
    _thermal_linear_cost!(fnm, :r_on_sup, get_on_sup_cost)
    _thermal_linear_cost!(fnm, :r_off_sup, get_off_sup_cost)
    return fnm
end

function _add_thermal_gen_blocks!(
    model::Model, unit_codes, p_aux_lims, n_periods, n_blocks
)
    @variable(
        model,
        p_aux[g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]] >= 0
    )
    # Add constraints linking `p` to `p_aux`
    p = model[:p]
    @constraint(
        model,
        generation_definition[g in unit_codes, t in 1:n_periods],
        p[g, t] == sum(p_aux[g, t, q] for q in 1:n_blocks[g][t])
    )
    # Add upper bounds to `p_aux` - formulation changes a bit if there is commitment or not
    if has_variable(model, "u")
        u = model[:u]
        @constraint(
            model,
            gen_block_limits[g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]],
            p_aux[g, t, q] <= p_aux_lims[g][t][q] * u[g, t]
        )
    else
        @constraint(
            model,
            gen_block_limits[g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]],
            p_aux[g, t, q] <= p_aux_lims[g][t][q]
        )
    end
    return model
end

function _thermal_variable_cost_objective!(model::Model, unit_codes, n_periods, n_blocks, Λ)
    p_aux = model[:p_aux]
    variable_cost = AffExpr(0.0)
    for g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]
        variable_cost += p_aux[g, t, q] * Λ[g][t][q]
    end
    _add_to_objective!(model, variable_cost)
    return model
end
