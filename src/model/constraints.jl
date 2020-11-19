function _generation_limits(; commitment::Bool)
    u_gt = commitment ? "u_{g, t}" : ""
    return """
        ``P^{\\min}_{g, t} $u_gt \\leq p_{g, t} \\leq P^{\\max}_{g, t} $u_gt, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    generation_limits!(fnm::FullNetworkModel)

Adds generation limit constraints to the full network model:

$(_generation_limits(commitment=true))

if `fnm.model` has commitment, or

$(_generation_limits(commitment=false))

if `fnm.model` does not have commitment.

The constraints added are named `generation_min` and `generation_max`.
"""
function generation_limits!(fnm::FullNetworkModel)
    @assert has_variable(fnm.model, "p")
    generation_limits!(
        fnm,
        Val(has_variable(fnm.model, "u")),
        get_unit_codes(ThermalGen, fnm.system),
        get_forecasts_horizon(fnm.system),
        get_pmin(fnm.system),
        get_pmax(fnm.system),
    )
    return fnm
end

function generation_limits!(
    fnm::FullNetworkModel, ::Val{true}, unit_codes, n_periods, Pmin, Pmax
)
    p = fnm.model[:p]
    u = fnm.model[:u]
    @constraint(
        fnm.model,
        generation_min[g in unit_codes, t in 1:n_periods],
        Pmin[g][t] * u[g, t] <= p[g, t]
    )
    @constraint(
        fnm.model,
        generation_max[g in unit_codes, t in 1:n_periods],
        p[g, t] <= Pmax[g][t] * u[g, t]
    )
    return fnm
end

function generation_limits!(
    fnm::FullNetworkModel, ::Val{false}, unit_codes, n_periods, Pmin, Pmax
)
    p = fnm.model[:p]
    @constraint(
        fnm.model,
        generation_min[g in unit_codes, t in 1:n_periods],
        Pmin[g][t] <= p[g, t]
    )
    @constraint(
        fnm.model,
        generation_max[g in unit_codes, t in 1:n_periods],
        p[g, t] <= Pmax[g][t]
    )
end
