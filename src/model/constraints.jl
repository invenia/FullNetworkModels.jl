@doc raw"""
    generation_limits!(fnm::FullNetworkModel)

Adds generation limit constraints to the full network model.

If `fnm` has commitment:

```math
P^{\min}_{g, t} u_{g, t} \leq p_{g, t} \leq P^{\max}_{g, t} u_{g, t}, \forall g \in \{\text{unit codes}\}, t \in 1, ..., T
```

If `fnm` does not have commitment:

```math
P^{\min}_{g, t} \leq p_{g, t} \leq P^{\max}_{g, t}, \forall g \in \{\text{unit codes}\}, t \in 1, ..., T
```
where `T` is the number of time periods defined in the forecasts in `system`.

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
