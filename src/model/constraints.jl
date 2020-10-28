@doc raw"""
    generation_limits!(fnm::FullNetworkModel)

If `fnm` has commitment:

```math
P^{\min}_{g, t} u_{g, t} \leq p_{g, t} \leq P^{\max}_{g, t} u_{g, t}, \forall g \in \{\text{unit codes}\}, t \in 1, ..., T
```

If `fnm` does not have commitment:

```math
P^{\min}_{g, t} \leq p_{g, t} \leq P^{\max}_{g, t}, \forall g \in \{\text{unit codes}\}, t \in 1, ..., T
```
where `T` is the number of time periods defined in the forecasts in `system`.
"""
function generation_limits!(fnm::FullNetworkModel)
    @assert _has_variable(fnm.model, "p")
    generation_limits!(
        fnm,
        Val(_has_variable(fnm.model, "u")),
        fnm.params.unit_codes,
        fnm.params.n_periods,
        fnm.params.forecasts.active_power_min,
        fnm.params.forecasts.active_power_max,
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
