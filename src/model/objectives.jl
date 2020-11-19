function _thermal_variable_cost_objective()
    return """
        ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} \\sum_{q \\in \\mathcal{Q}_{g, t}} p_{g, t, q} \\Lambda^{\\text{offer}}_{g, t, q}``
        """
end

function _thermal_variable_cost_constraints(; commitment)
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

$(_thermal_variable_cost_objective())

And adds the following constraints:

$(_thermal_variable_cost_constraints(commitment=true))

if `fnm.model` has commitment, or

$(_thermal_variable_cost_constraints(commitment=false))

if `fnm.model` does not have commitment.
"""
function thermal_variable_cost!(fnm::FullNetworkModel)
    @assert has_variable(fnm.model, "p")
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    offer_curves = get_offer_curves(fnm.system)
    # Get properties of the offer curves: prices, block MW limits, number of blocks
    Λ, p_aux_lims, n_blocks = _offer_curve_properties(offer_curves, n_periods)
    # Add variables and constraints for thermal generation blocks
    _add_thermal_gen_blocks!(fnm, unit_codes, p_aux_lims, n_periods, n_blocks)
    # Add thermal variable cost to objective
    _thermal_variable_cost_objective!(fnm, unit_codes, n_periods, n_blocks, Λ)
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
function thermal_noload_cost!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "u")
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecasts_horizon(system)
    cost_nl = get_noload_cost(system)
    u = model[:u]
    obj_nl = sum(cost_nl[g][t] * u[g, t] for g in unit_codes, t in 1:n_periods)
    _add_to_objective!(model, obj_nl)
    return fnm
end

function _add_thermal_gen_blocks!(fnm, unit_codes, p_aux_lims, n_periods, n_blocks)
    @variable(
        fnm.model,
        p_aux[g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]] >= 0
    )
    # Add constraints linking `p` to `p_aux`
    p = fnm.model[:p]
    @constraint(
        fnm.model,
        generation_definition[g in unit_codes, t in 1:n_periods],
        p[g, t] == sum(p_aux[g, t, q] for q in 1:n_blocks[g][t])
    )
    # Add upper bounds to `p_aux` - formulation changes a bit if there is commitment or not
    if has_variable(fnm.model, "u")
        u = fnm.model[:u]
        @constraint(
            fnm.model,
            gen_block_limits[g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]],
            p_aux[g, t, q] <= p_aux_lims[g][t][q] * u[g, t]
        )
    else
        @constraint(
            fnm.model,
            gen_block_limits[g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]],
            p_aux[g, t, q] <= p_aux_lims[g][t][q]
        )
    end
    return fnm
end

function _thermal_variable_cost_objective!(fnm, unit_codes, n_periods, n_blocks, Λ)
    model = fnm.model
    p_aux = model[:p_aux]
    variable_cost = AffExpr(0.0)
    for g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]
        variable_cost += p_aux[g, t, q] * Λ[g][t][q]
    end
    _add_to_objective!(model, variable_cost)
    return fnm
end
