# Define functions so that `_latex` can be dispatched over them
function _obj_thermal_variable_cost! end
function _var_thermal_gen_blocks! end
function obj_ancillary_costs! end
function obj_thermal_noload_cost! end
function obj_thermal_startup_cost! end

function _latex(::typeof(_obj_thermal_variable_cost!))
    return """
    ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} \\sum_{q \\in \\mathcal{Q}_{g, t}} p^{\\text{aux}}_{g, t, q} \\Lambda^{\\text{offer}}_{g, t, q}``
    """
end

function _latex(::typeof(_var_thermal_gen_blocks!); commitment)
    u_gt = commitment ? "u_{g, t}" : ""
    return """
        ``0 \\leq p^{\\text{aux}}_{g, t, q} \\leq \\bar{P}_{g, t, q} $u_gt, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}, q \\in \\mathcal{Q}_{g, t}`` \n
        ``p_{g, t} = \\sum_{q \\in \\mathcal{Q}_{g, t}} p^{\\text{aux}}_{g, t, q}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    obj_thermal_variable_cost!(fnm::FullNetworkModel)

Adds the variable cost related to thermal generators by using auxiliary generation variables
that multiply the offer prices. The variables `p_aux` are indexed, respectively, by the unit
codes of the thermal generators in `system`, by the time periods considered, and by the
offer block number.

Adds to the objective function:

$(_latex(_obj_thermal_variable_cost!))

And adds the following constraints:

$(_latex(_var_thermal_gen_blocks!; commitment=true))

if `fnm.model` has commitment, or

$(_latex(_var_thermal_gen_blocks!; commitment=false))

if `fnm.model` does not have commitment.
"""
function obj_thermal_variable_cost!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    @assert has_variable(model, "p")
    unit_codes = get_unit_codes(ThermalGen, system)
    n_periods = get_forecast_horizon(system)
    offer_curves = get_offer_curves(system)
    # Get properties of the offer curves: prices, block MW limits, number of blocks
    Λ, p_aux_lims, n_blocks = _curve_properties(offer_curves, n_periods)
    # Add variables and constraints for thermal generation blocks
    _var_thermal_gen_blocks!(model, unit_codes, p_aux_lims, n_periods, n_blocks)
    # Add thermal variable cost to objective
    _obj_thermal_variable_cost!(model, unit_codes, n_periods, n_blocks, Λ)
    return fnm
end

function _latex(::typeof(obj_thermal_noload_cost!))
    return """
        ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} C^{\\text{nl}}_{g, t} u_{g, t}``
        """
end

"""
    obj_thermal_noload_cost!(fnm::FullNetworkModel)

Adds the no-load cost of thermal generators to the model formulation:

$(_latex(obj_thermal_noload_cost!))
"""
function obj_thermal_noload_cost!(fnm::FullNetworkModel)
    return _obj_thermal_linear_cost!(fnm, :u, get_noload_cost)
end

function _latex(::typeof(obj_thermal_startup_cost!))
    return """
        ``\\sum_{t \\in \\mathcal{T}} \\sum_{g \\in \\mathcal{G}} C^{\\text{st}}_{g, t} v_{g, t}``
        """
end

"""
    obj_thermal_startup_cost!(fnm::FullNetworkModel)

Adds the start-up cost of thermal generators to the model formulation:

$(_latex(obj_thermal_startup_cost!))
"""
function obj_thermal_startup_cost!(fnm::FullNetworkModel)
    return _obj_thermal_linear_cost!(fnm, :v, get_startup_cost)
end

function _latex(::typeof(obj_ancillary_costs!))
    return """
        ``\\sum_{g \\in \\mathcal{G}} \\sum_{t \\in \\mathcal{T}} (C^{\\text{reg}}_{g, t} r^{\\text{reg}}_{g, t} + C^{\\text{spin}}_{g, t} r^{\\text{spin}}_{g, t} + C^{\\text{on-sup}}_{g, t} r^{\\text{on-sup}}_{g, t} + C^{\\text{off-sup}}_{g, t} r^{\\text{off-sup}}_{g, t})``
        """
end

"""
    obj_ancillary_costs!(fnm::FullNetworkModel)

Adds the ancillary service costs related to thermal generators, namely regulation, spinning,
online supplemental, and offline supplemental reserves.

Adds to the objective function:

$(_latex(obj_ancillary_costs!))
"""
function obj_ancillary_costs!(fnm::FullNetworkModel)
    _obj_thermal_linear_cost!(
        fnm, :r_reg, get_regulation_cost; unit_codes=get_regulation_providers(fnm.system)
    )
    _obj_thermal_linear_cost!(
        fnm, :r_spin, get_spinning_cost; unit_codes=get_spinning_providers(fnm.system)
    )
    _obj_thermal_linear_cost!(
        fnm, :r_on_sup, get_on_sup_cost; unit_codes=get_on_sup_providers(fnm.system)
    )
    _obj_thermal_linear_cost!(
        fnm, :r_off_sup, get_off_sup_cost; unit_codes=get_off_sup_providers(fnm.system)
    )
    return fnm
end

function _var_thermal_gen_blocks!(
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

function _obj_thermal_variable_cost!(model::Model, unit_codes, n_periods, n_blocks, Λ)
    p_aux = model[:p_aux]
    variable_cost = AffExpr(0.0)
    for g in unit_codes, t in 1:n_periods, q in 1:n_blocks[g][t]
        variable_cost += p_aux[g, t, q] * Λ[g][t][q]
    end
    _add_to_objective!(model, variable_cost)
    return model
end

"""
    obj_bids!(fnm::FullNetworkModel)

Adds the bid curves related to virtual supply and demand bids as well as price-sensitive
demand bids. Uses auxiliary variables that multiply the bid prices. The variables `*_aux`
are indexed, respectively, by the bid names in `system`, by the time periods considered,
and by the bid block number.

Adds to the objective function:

$(_latex(TODO))

And adds the following constraints:

$(_latex(TODO))
"""
function obj_bids!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    n_periods = get_forecast_horizon(system)
    for (bidtype, v_name) in (
        (Increment, "inc"), (Decrement, "dec"), (PriceSensitiveDemand, "psd")
    )
        bid_names = get_bid_names(bidtype, system)
        bids = get_bid_curves(bidtype, system)
        # Get properties of the bid curves: prices, block MW limits, number of blocks
        Λ, block_lims, n_blocks = _curve_properties(bids, n_periods; blocks=true)
        # Add variables and constraints for bid blocks and cost to objective function
        _var_bid_blocks!(model, bid_names, block_lims, n_periods, n_blocks, v_name)
        _obj_thermal_variable_cost!(model, unit_codes, n_periods, n_blocks, Λ)
    end
    return fnm
end

function _var_bid_blocks!(model::Model, bid_names, block_lims, n_periods, n_blocks, v_name)
    # Define variable / constraint names – this function is used for all bid types
    v = Symbol(v_name)
    v_aux = Symbol(v_name, "_aux")
    def = Symbol(v, "_definition")
    lims = Symbol(v, "_block_limits")

    @eval @variable(
        model,
        $v_aux[b in bid_names, t in 1:n_periods, q in 1:n_blocks[g][t]] >= 0
    )
    @eval @constraint(
        model,
        $def[b in bid_names, t in 1:n_periods],
        $v[g, t] == sum($v_aux[b, t, q] for q in 1:n_blocks[b][t])
    )
    @eval @constraint(
        model,
        $lims[b in bid_names, t in 1:n_periods, q in 1:n_blocks[g][t]],
        $v_aux[g, t, q] <= block_lims[g][t][q]
    )
    return model
end
