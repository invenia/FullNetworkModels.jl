@doc raw"""
    thermal_variable_cost!(fnm::FullNetworkModel)

Adds the variable cost related to thermal generators by using auxiliary generation variables
that multiply the offer prices. The variables `p_aux` are indexed, respectively, by the unit
codes of the thermal generators in `system`, by the time periods considered, and by the
offer block number.

Adds to the objective function:
```math
\sum_{t \in 1, ..., T} \sum_{g \in \{\text{unit codes}\}} \sum_{q in 1, ..., Q_{g, t}} p_{g, t, q} \Lambda^{\text{offer}}_{g, t, q}
```

And adds the following constraints:

```math
0 \leq p^{\text{aux}}_{g, t, q} \leq \bar{P}_{g, t, q} u_{g, t}, \forall g \in \{\text{unit codes}\}, t \in 1, ..., T, q \in 1, ..., Q_{g, t} \\
p_{g, t} = \sum_{q \in 1, ..., Q_{g, t}} p_{g, t, q}, \forall g \in \{\text{unit codes}\}, t \in 1, ..., T
```
where `T` is the number of time periods defined in the forecasts in `system` and `Q_{g, t}`
is the number of offer blocks.
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

"""
    _offer_curve_properties(offer_curves, n_periods) -> Dict, Dict, Dict

Returns dictionaries for several properties of offer curves, namely the prices, block
generation limits and number of blocks for each generator in each time period. All
dictionaries have the unit codes as keys.
"""
function _offer_curve_properties(offer_curves, n_periods)
    prices = Dict{Int, Vector{Vector{Float64}}}()
    limits = Dict{Int, Vector{Vector{Float64}}}()
    n_blocks = Dict{Int, Vector{Int}}()
    for (g, offer_curve) in offer_curves
        prices[g] = [first.(offer_curve[i]) for i in 1:n_periods]
        limits[g] = [last.(offer_curve[i]) for i in 1:n_periods]
        n_blocks[g] = length.(limits[g])
    end
    # Change block MW values to block limits - e.g. if the MW values are (50, 100, 200),
    # the corresponding limits of each block are (50, 50, 100).
    for g in keys(n_blocks), t in 1:n_periods, q in n_blocks[g][t]:-1:2
        limits[g][t][q] -= limits[g][t][q - 1]
    end
    return prices, limits, n_blocks
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
    p_aux = fnm.model[:p_aux]
    obj = objective_function(fnm.model)
    variable_cost = AffExpr(0.0)
    for g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]
        variable_cost += p_aux[g, t, q] * Λ[g][t][q]
    end
    add_to_expression!(obj, variable_cost)
    @objective(fnm.model, Min, obj)
    return fnm
end
