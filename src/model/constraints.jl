# Define functions so that `latex` can be dispatched over them
function con_ancillary_limits_ed! end
function con_ancillary_limits_uc! end
function con_energy_balance_ed! end
function con_energy_balance_uc! end
function _con_generation_limits_uc! end
function _con_generation_limits_ed! end
function con_operating_reserve_requirements! end
function con_regulation_requirements! end
function con_ancillary_ramp_rates! end
function con_generation_ramp_rates! end
function _con_nodal_net_injection_ed! end
function _con_nodal_net_injection_uc! end
function _con_branch_flows! end
function _con_branch_flow_limits! end
function _con_branch_flow_slacks! end
function con_thermal_branch! end
function con_must_run! end
function con_availability! end

function latex(::typeof(_con_generation_limits_uc!))
    return """
        ``P^{\\min}_{g, t} u_{g, t} \\leq p_{g, t} \\leq P^{\\max}_{g, t} u_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function latex(::typeof(_con_generation_limits_ed!))
    return """
        ``P^{\\min}_{g, t} U_{g, t} \\leq p_{g, t} \\leq P^{\\max}_{g, t} U_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    con_generation_limits!(fnm::FullNetworkModel{UC})

Add generation limit constraints to the full network model:

$(latex(_con_generation_limits_uc!))

The constraints added are named `generation_min` and `generation_max`.
"""
function con_generation_limits!(fnm::FullNetworkModel{<:UC})
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes

    p = model[:p]
    u = model[:u]
    unit_codes = keys(get_generators(fnm.system))
    Pmin = _keyed_to_dense(get_pmin_timeseries(system))
    Pmax = _keyed_to_dense(get_pmax_timeseries(system))

    @constraint(
        model,
        generation_min[g in unit_codes, t in datetimes],
        Pmin[g, t] * u[g, t] <= p[g, t]
    )
    @constraint(
        model,
        generation_max[g in unit_codes, t in datetimes],
        p[g, t] <= Pmax[g, t] * u[g, t]
    )
    return fnm
end

"""
    con_generation_limits!(fnm::FullNetworkModel{ED})

Add generation limit constraints to the full network model:

$(latex(_con_generation_limits_ed!))

The constraints added are named `generation_min` and `generation_max`.
"""
function con_generation_limits!(fnm::FullNetworkModel{<:ED})
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes

    p = model[:p]
    unit_codes = keys(get_generators(fnm.system))
    U = _keyed_to_dense(get_commitment_status(system))
    Pmin = _keyed_to_dense(get_pmin_timeseries(system))
    Pmax = _keyed_to_dense(get_pmax_timeseries(system))

    @constraint(
        model,
        generation_min[g in unit_codes, t in datetimes],
        Pmin[g, t] * U[g, t] <= p[g, t]
    )
    @constraint(
        model,
        generation_max[g in unit_codes, t in datetimes],
        p[g, t] <= Pmax[g, t] * U[g, t]
    )
    return fnm
end

function latex(::typeof(con_ancillary_limits_uc!))
    return """
        ``p_{g, t} + r^{\\text{reg}}_{g, t} + r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} \\leq P^{\\max}_{g, t} (u_{g, t} - u^{\\text{reg}}_{g, t}) + P^{\\text{reg-max}}_{g, t} u^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``p_{g, t} - r^{\\text{reg}}_{g, t} \\geq P^{\\min}_{g, t} (u_{g, t} - u^{\\text{reg}}_{g, t}) + P^{\\text{reg-min}}_{g, t} u^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{reg}}_{g, t} \\leq 0.5 (P^{\\text{reg-max}}_{g, t} - P^{\\text{reg-min}}_{g, t}) u^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} \\leq (P^{\\max}_{g, t} - P^{\\min}_{g, t}) u_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\leq (P^{\\max}_{g, t} - P^{\\min}_{g, t}) (1 - u_{g, t}), \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}``
        """
end
function latex(::typeof(con_ancillary_limits_ed!))
    return """
        ``p_{g, t} + r^{\\text{reg}}_{g, t} + r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} \\leq P^{\\max}_{g, t} (U_{g, t} - U^{\\text{reg}}_{g, t}) + P^{\\text{reg-max}}_{g, t} U^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``p_{g, t} - r^{\\text{reg}}_{g, t} \\geq P^{\\min}_{g, t} (U_{g, t} - U^{\\text{reg}}_{g, t}) + P^{\\text{reg-min}}_{g, t} U^{\\text{reg}}_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} \\leq (P^{\\max}_{g, t} - P^{\\min}_{g, t}) U_{g, t}, \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\leq (P^{\\max}_{g, t} - P^{\\min}_{g, t}) (1 - U_{g, t}), \\forall g \\in \\mathcal{G}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    con_ancillary_limits!(fnm::FullNetworkModel{UC})

Add ancillary service limit constraints to the full network model:

$(latex(con_ancillary_limits_uc!))

The constraints added are named, respectively, `ancillary_max`, `ancillary_min`,
`regulation_max`, `spin_and_sup_max`, and `off_sup_max`.
"""
function con_ancillary_limits!(fnm::FullNetworkModel{<:UC})
    system = fnm.system
    datetimes = fnm.datetimes
    unit_codes = keys(get_generators(fnm.system))
    Pmax = _keyed_to_dense(get_pmax_timeseries(system))
    Pregmax = _keyed_to_dense(get_regmax_timeseries(system))
    Pmin = _keyed_to_dense(get_pmin_timeseries(system))
    Pregmin = _keyed_to_dense(get_regmin_timeseries(system))

    model = fnm.model
    u = model[:u]
    u_reg = model[:u_reg]

    _con_ancillary_max!(model, unit_codes, datetimes, Pmax, Pregmax, u, u_reg)
    _con_ancillary_min!(model, unit_codes, datetimes, Pmin, Pregmin, u, u_reg)
    _con_regulation_max!(model, unit_codes, datetimes, Pregmin, Pregmax, u_reg)
    _con_spin_and_sup_max!(model, unit_codes, datetimes, Pmin, Pmax, u)
    _con_off_sup_max!(model, unit_codes, datetimes, Pmin, Pmax, u)
    _con_zero_non_providers!(model, system, unit_codes, datetimes, u_reg)
    return fnm
end

"""
    con_ancillary_limits!(fnm::FullNetworkModel{ED})

Add ancillary service limit constraints to the full network model:

$(latex(con_ancillary_limits_ed!))

The constraints added are named, respectively, `ancillary_max`, `ancillary_min`,
`spin_and_sup_max`, and `off_sup_max`.
"""
function con_ancillary_limits!(fnm::FullNetworkModel{<:ED})
    system = fnm.system
    datetimes = fnm.datetimes
    unit_codes = keys(get_generators(fnm.system))
    Pmax = _keyed_to_dense(get_pmax_timeseries(system))
    Pregmax = _keyed_to_dense(get_regmax_timeseries(system))
    Pmin = _keyed_to_dense(get_pmin_timeseries(system))
    Pregmin = _keyed_to_dense(get_regmin_timeseries(system))
    U = _keyed_to_dense(get_commitment_status(system))
    U_reg = _keyed_to_dense(get_commitment_reg_status(system))

    model = fnm.model
    _con_ancillary_max!(model, unit_codes, datetimes, Pmax, Pregmax, U, U_reg)
    _con_ancillary_min!(model, unit_codes, datetimes, Pmin, Pregmin, U, U_reg)
    _con_spin_and_sup_max!(model, unit_codes, datetimes, Pmin, Pmax, U)
    _con_off_sup_max!(model, unit_codes, datetimes, Pmin, Pmax, U)
    _con_zero_non_providers!(model, system, unit_codes, datetimes)
    return fnm
end

function latex(::typeof(con_regulation_requirements!))
    return """
        ``\\sum_{g \\in \\mathcal{G}_{z}} r^{\\text{reg}}_{g, t} \\geq R^{\\text{reg-req}}_{z}, \\forall z \\in \\mathcal{Z}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    con_regulation_requirements!(fnm::FullNetworkModel; slack)

Adds zonal and market-wide regulation requirements to the full network model:

$(latex(con_regulation_requirements!))

Note:
    - For `fnm::FullNetworkModel{<:ED}` this defaults to a soft constraint (`slack=1e6`).
    - For `fnm::FullNetworkModel{<:UC}` this defaults to a hard constraint (`slack=nothing`).
"""
function con_regulation_requirements!(fnm::FullNetworkModel{<:UC}; slack=nothing)
    return con_regulation_requirements!(fnm, slack)
end

function con_regulation_requirements!(fnm::FullNetworkModel{<:ED}; slack=1e6)
    return con_regulation_requirements!(fnm, slack)
end

function con_regulation_requirements!(fnm::FullNetworkModel, slack)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    reserve_zones = keys(get_zones(system))
    zone_gens = gens_per_zone(system)
    reg_requirements = get_regulation_requirements(system)
    r_reg = model[:r_reg]
    @constraint(
        model,
        regulation_requirements[z in reserve_zones, t in datetimes],
        sum(r_reg[g, t] for g in zone_gens[z]) >= reg_requirements[z]
    )
    if slack !== nothing
        # Soft constraints, add slacks
        @variable(model, sl_reg_req[z in reserve_zones, t in datetimes] >= 0)
        for z in reserve_zones, t in datetimes
            set_normalized_coefficient(regulation_requirements[z, t], sl_reg_req[z, t], 1.0)
            # Add slack penalty to the objective
            set_objective_coefficient(model, sl_reg_req[z, t], slack)
        end
    end
    return fnm
end

function latex(::typeof(con_operating_reserve_requirements!))
    return """
        ``\\sum_{g \\in \\mathcal{G}_{z}} (r^{\\text{reg}}_{g, t} + r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} + r^{\\text{off-sup}}_{g, t}) \\geq R^{\\text{OR-req}}_{z}, \\forall z \\in \\mathcal{Z}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    con_operating_reserve_requirements!(fnm::FullNetworkModel)

Adds zonal and market-wide operating reserve requirements to the full network model:

$(latex(con_operating_reserve_requirements!))
"""
function con_operating_reserve_requirements!(fnm::FullNetworkModel{<:UC}; slack=nothing)
    return con_operating_reserve_requirements!(fnm, slack)
end

function con_operating_reserve_requirements!(fnm::FullNetworkModel{<:ED}; slack=1e6)
    return con_operating_reserve_requirements!(fnm, slack)
end

function con_operating_reserve_requirements!(fnm::FullNetworkModel, slack)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    reserve_zones = keys(get_zones(system))
    zone_gens = gens_per_zone(system)
    or_requirements = get_operating_reserve_requirements(system)
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    @constraint(
        model,
        operating_reserve_requirements[z in reserve_zones, t in datetimes],
        sum(
            r_reg[g, t] + r_spin[g, t] + r_on_sup[g, t] + r_off_sup[g, t]
                for g in zone_gens[z]
        ) >= or_requirements[z]
    )
    if slack !== nothing
        # Soft constraints, add slacks
        @variable(model, sl_or_req[z in reserve_zones, t in datetimes] >= 0)
        for z in reserve_zones, t in datetimes
            set_normalized_coefficient(operating_reserve_requirements[z, t], sl_or_req[z, t], 1.0)
            # Add slack penalty to the objective
            set_objective_coefficient(model, sl_or_req[z, t], slack)
        end
    end
    return fnm
end

function latex(::typeof(con_ancillary_ramp_rates!))
    return """
        ``r^{\\text{reg}}_{g, t} \\leq 5 RR_{g}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} + r^{\\text{on-sup}}_{g, t} + r^{\\text{off-sup}}_{g, t} \\leq 10 RR_{g}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function latex(::typeof(con_generation_ramp_rates!))
    return """
        ``p_{g, t} - p_{g, t - 1} \\leq \\Delta t RR_{g} u_{g, t - 1} + SU_{g} v_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T} \\setminus \\{1\\}`` \n
        ``p_{g, 1} - P^{0}_{g} \\leq \\Delta t RR_{g} U^{0}_{g} + SU_{g} v_{g, 1}, \\forall g \\in \\mathcal{G}^{a}_{1}`` \n
        ``p_{g, t - 1} - p_{g, t} \\leq \\Delta t RR_{g} u_{g, t} + SD_{g} w_{g, t} + (1 - A_{g, t}) P^{\\max}_{g, t-1}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T} \\setminus \\{1\\}`` \n
        ``P^{0}_{g} - p_{g, 1} \\leq \\Delta t RR_{g} u_{g, 1} + SD_{g} w_{g, 1}, \\forall g \\in \\mathcal{G}^{a}_{1}``
        """
end

function latex(::typeof(con_energy_balance_ed!))
    return """
        ``\\sum_{g \\in \\mathcal{G}} p_{g, t} =
        \\sum_{f \\in \\mathcal{F}} D_{f, t}, \\forall t \\in \\mathcal{T}``
        """
end
function latex(::typeof(con_energy_balance_uc!))
    return """
        ``\\sum_{g \\in \\mathcal{G}} p_{g, t} + \\sum_{i \\in \\mathcal{I}} inc_{i, t} =
        \\sum_{f \\in \\mathcal{F}} D_{f, t} + \\sum_{d \\in \\mathcal{D}} dec_{d, t} + \\sum_{s \\in \\mathcal{S}} psd_{s, t}, \\forall t \\in \\mathcal{T}``
        """
end

"""
    con_energy_balance!(fnm::FullNetworkModel{ED})

Adds the energy balance constraints to the full network model. The constraints ensure that
the total generation in the system meets the demand in each time period, assuming no loss:

$(latex(con_energy_balance_ed!))

The constraint is named `energy_balance`.
"""
function con_energy_balance!(fnm::FullNetworkModel{<:ED}; slack=nothing)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    unit_codes = keys(get_generators(fnm.system))
    D = _keyed_to_dense(get_load_timeseries(system))
    load_names = axes(D, 1)
    p = model[:p]
    @constraint(
        model,
        energy_balance[t in datetimes],
        sum(p[g, t] for g in unit_codes) == sum(D[f, t] for f in load_names)
    )
    # If the constraints are supposed to be soft constraints, add slacks
    # We need one slack for excess load and one for excess generation
    if slack !== nothing
        @variable(model, sl_eb_gen[t in datetimes] >= 0)
        @variable(model, sl_eb_load[t in datetimes] >= 0)
        for t in datetimes
            set_normalized_coefficient(energy_balance[t], sl_eb_gen[t], 1.0)
            set_normalized_coefficient(energy_balance[t], sl_eb_load[t], -1.0)
        end
        _add_to_objective!(model, slack * (sum(sl_eb_gen) + sum(sl_eb_load)))
    end
    return fnm
end

"""
    con_energy_balance!(fnm::FullNetworkModel{UC})

Adds the energy balance constraints to the full network model. The constraints ensure that
the total generation in the system meets the demand in each time period, including bids such
as increments, decrements, and price-sensitive demands, assuming no loss:

$(latex(con_energy_balance_uc!))

The constraint is named `energy_balance`.
"""
function con_energy_balance!(fnm::FullNetworkModel{<:UC}; slack=nothing)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    unit_codes = keys(get_generators(fnm.system))
    D = _keyed_to_dense(get_load_timeseries(system))
    load_names = axes(D, 1)

    inc_names = axiskeys(get_bids_timeseries(fnm.system, :increment), 1)
    dec_names = axiskeys(get_bids_timeseries(fnm.system, :decrement), 1)
    psd_names = axiskeys(get_bids_timeseries(fnm.system, :price_sensitive_demand), 1)

    p = model[:p]
    inc = model[:inc]
    dec = model[:dec]
    psd = model[:psd]
    @constraint(
        model,
        energy_balance[t in datetimes],
        sum(p[g, t] for g in unit_codes) + sum(inc[i, t] for i in inc_names) ==
            sum(D[f, t] for f in load_names) + sum(dec[d, t] for d in dec_names) +
            sum(psd[s, t] for s in psd_names)
    )
    # If the constraints are supposed to be soft constraints, add slacks
    # We need one slack for excess load and one for excess generation
    if slack !== nothing
        @variable(model, sl_eb_gen[t in datetimes] >= 0)
        @variable(model, sl_eb_load[t in datetimes] >= 0)
        for t in datetimes
            set_normalized_coefficient(energy_balance[t], sl_eb_gen[t], 1.0)
            set_normalized_coefficient(energy_balance[t], sl_eb_load[t], -1.0)
        end
        _add_to_objective!(model, slack * (sum(sl_eb_gen) + sum(sl_eb_load)))
    end
    return fnm
end

function latex(::typeof(_con_nodal_net_injection_ed!))
    return """
        ``p^{net}_{n, t} = \\sum_{g \\in \\mathcal{G}_n} p_{g, t} -
        \\sum_{f \\in \\mathcal{F}_n} D_{f, t}, \\forall n \\in \\mathcal{V}, t \\in \\mathcal{T}``
        """
end
function latex(::typeof(_con_nodal_net_injection_uc!))
    return """
        ``p^{net}_{n, t} = \\sum_{g \\in \\mathcal{G_n}} p_{g, t} + \\sum_{i \\in \\mathcal{I}_n} inc_{i, t} -
        \\sum_{f \\in \\mathcal{F}_n} D_{f, t} - \\sum_{d \\in \\mathcal{D}_n} dec_{d, t} -
        \\sum_{s \\in \\mathcal{S}_n} psd_{s, t}, \\forall n \\in \\mathcal{V}, t \\in \\mathcal{T}``
        """
end

"""
    _con_nodal_net_injection!(fnm::FullNetworkModel{ED}, bus_names, D, unit_codes_perbus, load_names_perbus)

Adds the Net Nodal Injection constraints to the full network model. The constraints calculate
the net injection per node for all the buses of the system.

The Net Nodal Injection for the Economic Dispatch is formulated as:

$(latex(_con_nodal_net_injection_ed!))

The constraint is named `nodal_net_injection`.
"""
function _con_nodal_net_injection!(fnm::FullNetworkModel{<:ED}, bus_names, D, unit_codes_perbus, load_names_perbus)
    model = fnm.model
    @variable(model, p_net[n in bus_names, t in fnm.datetimes])
    p = model[:p]
    @constraint(
        model,
        nodal_net_injection[n in bus_names, t in fnm.datetimes],
        p_net[n, t] ==
            sum(p[g, t] for g in unit_codes_perbus[n]) -
            sum(D[f, t] for f in load_names_perbus[n])
    )
    return fnm
end

"""
    _con_nodal_net_injection!(fnm::FullNetworkModel{UC}, bus_names, D, unit_codes_perbus, load_names_perbus)

Adds the Net Nodal Injection constraints to the full network model. The constraints calculate
the net injection per node for all the buses of the system.

The Net Nodal Injection for the Unit Commitment is formulated as:

$(latex(_con_nodal_net_injection_uc!))

The constraint is named `nodal_net_injection`.
"""
function _con_nodal_net_injection!(fnm::FullNetworkModel{<:UC}, bus_names, D, unit_codes_perbus, load_names_perbus)
    model = fnm.model
    system = fnm.system
    inc_names_perbus = get_incs_per_bus(system)
    dec_names_perbus = get_decs_per_bus(system)
    psd_names_perbus = get_psds_per_bus(system)
    @variable(model, p_net[n in bus_names, t in fnm.datetimes])
    p = model[:p]
    inc = model[:inc]
    dec = model[:dec]
    psd = model[:psd]
    @constraint(
        model,
        nodal_net_injection[n in bus_names, t in fnm.datetimes],
        p_net[n, t] ==
        sum(p[g, t] for g in unit_codes_perbus[n]) +
            sum(inc[i, t] for i in inc_names_perbus[n]) -
            sum(D[f, t] for f in load_names_perbus[n]) -
            sum(dec[d, t] for d in dec_names_perbus[n]) -
            sum(psd[s, t] for s in psd_names_perbus[n])
    )
    return fnm
end

function latex(::typeof(_con_branch_flows!))
    return """
        ``fl^{c}_{m, t} = \\sum_{n \\in \\mathcal{N}_m} PTDF_{m, n} p^{net}_{n, t} + \\sum_{l \\in \\mathcal{L}_c} LODF_{m, l, c} fl^{0}_{l, t},
        \\forall m \\in \\mathcal{M}_0, t \\in \\mathcal{T}, c \\in \\mathcal{C}``
        """
end

"""
    _con_branch_flows!(
        fnm::FullNetworkModel,
        mon_branches_names,
        branches_names_monitored_or_out,
        ptdf,
        lodfs
    )

Adds the branch power flow constraints for all scenarios of the system to the full network
model. The scenarios include the base case and selected contingencies. The constraints
calculate the power flow through the "m" branches_names_monitored_or_out (Lines and Transformers).

The branch power flows for the base case and contingencies are calculated as:

$(latex(_con_branch_flows!))

Where the LODF for the base-case is zero.

The constraints are named `branch_flows_base` for the base case and `branch_flows_conting`
for the contingencies.
"""
function _con_branch_flows!(
    fnm::FullNetworkModel,
    mon_branches_names,
    branches_names_monitored_or_out,
    ptdf,
    lodfs
)
    model = fnm.model
    datetimes = fnm.datetimes
    p_net = model[:p_net]
    @assert axiskeys(ptdf, 2) == axes(p_net, 1) # we need this for vector multiplication
    contingencies = collect(keys(lodfs))
    all_scenarios = vcat("base_case", contingencies)
    @variable(
        model, fl[m in branches_names_monitored_or_out, t in datetimes, c in all_scenarios]
    )
    branches_out_per_scenario_names = map(l -> axes(l, 2), lodfs)
    # Compute this multiplication all at once for performance
    ptdf_times_pnet = ptdf(branches_names_monitored_or_out, :) * p_net.data
    name_mapping = Dict(branches_names_monitored_or_out .=> 1:length(branches_names_monitored_or_out))
    time_mapping = Dict(datetimes .=> 1:length(datetimes))
    @constraint(
        model,
        branch_flows_base[m in branches_names_monitored_or_out, t in datetimes],
        fl[m, t, "base_case"] == ptdf_times_pnet[name_mapping[m], time_mapping[t]]
    )
    @constraint(
        model,
        branch_flows_conting[m in mon_branches_names, t in datetimes, c in contingencies],
        fl[m, t, c] == fl[m, t, "base_case"] + sum(
            lodfs[c][m, l] * fl[l, t, "base_case"] for l in branches_out_per_scenario_names[c]
        )
    )
    return fnm
end

function latex(::typeof(_con_branch_flow_limits!))
    return """
        ``-FL^{rate}_{m, t, c} -sl1^{fl}_{m, t, c} -sl2^{fl}_{m, t, c} <= fl^{c}_{m, t} <= FL^{rate}_{m, t, c} +sl1^{fl}_{m, t, c} +sl2^{fl}_{m, t, c}``
        """
end

"""
    _con_branch_flow_limits!(fnm::FullNetworkModel, mon_branches_names, mon_branches_rates_a, mon_branches_rates_b, contingencies)

Adds the thermal branch constraints for all scenarios of the system to the full network model.
The scenarios include the base case and selected contingencies. The constraints ensure that
the power flow through the "m" monitored lines and transformers is smaller than the
transmission limit in both directions (Power flowing from bus "i" to bus "j" and from bus "j"
to bus "i").

The thermal branch constraints for the base case and contingencies are formulated as:

$(latex(_con_branch_flow_limits!))

Where the Rate A will be used for the base case, and the rate B will be used for the
contingencies.

The constraint is named `branch_flow_max` for the high boundary and `branch_flow_min`
for the lower boundary.
"""
function _con_branch_flow_limits!(
    fnm::FullNetworkModel,
    mon_branches,
    mon_branches_names,
    contingencies
)
    model = fnm.model
    fl = model[:fl]
    sl1_fl = model[:sl1_fl]
    sl2_fl = model[:sl2_fl]
    # Base case
    @constraint(
        model,
        branch_flow_max_base[m in mon_branches_names, t in fnm.datetimes, c in ["base_case"]],
        fl[m, t, c] <= mon_branches[m].rate_a + sl1_fl[m, t, c] + sl2_fl[m, t, c]
    )
    @constraint(
        model,
        branch_flow_min_base[m in mon_branches_names, t in fnm.datetimes, c in ["base_case"]],
        fl[m, t, c] >= - mon_branches[m].rate_a - sl1_fl[m, t, c] - sl2_fl[m, t, c]
    )
    # Contingency Scenarios
    @constraint(
        model,
        branch_flow_max_cont[m in mon_branches_names, t in fnm.datetimes, c in contingencies],
        fl[m, t, c] <= mon_branches[m].rate_b + sl1_fl[m, t, c] + sl2_fl[m, t, c]
    )
    @constraint(
        model,
        branch_flow_min_cont[m in mon_branches_names, t in fnm.datetimes, c in contingencies],
        fl[m, t, c] >= - mon_branches[m].rate_b - sl1_fl[m, t, c] - sl2_fl[m, t, c]
    )
    return fnm
end

function latex(::typeof(_con_branch_flow_slacks!))
    return """
    ``0 <= sl1^{fl}_{m, t, c} <= \\bar{SL1}^{fl}_{m, t, c}`` \n
    ``0 <= sl2^{fl}_{m, t, c}``
    """
end
"""
     _con_branch_flow_slacks!(
         fnm::FullNetworkModel,
         mon_branches_names,
         mon_branches_rates_a,
         mon_branches_rates_b,
         mon_branches_break_points,
         mon_branches_penalties,
         contingencies
    )

Adds the power flow slack penalty constraints for all scenarios of the system to the full
network model. The scenarios include the base case and selected contingencies.
The constraints ensure that the power flow through the "m" monitored lines and transformers
is penalised according to the branch breaking points and penalties.

The power flow slack penalty constraints for all scenarios are formulated as:

$(latex(_con_branch_flow_slacks!))

The Breakpoints are the percentage value of the Branch Rate in which the penalty for branch
flow changes. A branch could have one, two or no break-points. For example a Branch of 75MW
rate (FL) with one breakpoint at [100%] of the line rate will have a corresponding penalty
"Penalty1" for any flow above 100% (75MW). For a branch with two break-points [100%, 110%] will
have a penalty "Penalty1" for any flow in betweeen 100% (75MW) and 110% (82.5MW), and for any
MW above the 110% of the branch rate, the penalty will be "Penalty2". Finally a branch with no
break-points, the constraint should be a hard constraint. Thus, the slacks for each case should
be:

No break-points:
sl1^{fl}_{m, t, c} = 0
sl2^{fl}_{m, t, c} = 0

One break-points:
sl1^{fl}_{m, t, c} = 0
0 <= sl2^{fl}_{m, t, c}

Two break-points:
0 <= sl1^{fl}_{m, t, c} <= (110% - 100%)*75MW/(100*Sbase)
0 <= sl2^{fl}_{m, t, c}

The constraint is named `branch_flow_sl1_max` for the first step slack and `branch_flow_sl2_max`
for the second step slack.
"""
function _con_branch_flow_slacks!(
    fnm::FullNetworkModel,
    mon_branches,
    mon_branches_names,
    contingencies
)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    all_scenarios = vcat("base_case", contingencies)
    #Add slacks
    @variable(model, sl1_fl[m in mon_branches_names, t in datetimes, c in all_scenarios] >= 0)
    @variable(model, sl2_fl[m in mon_branches_names, t in datetimes, c in all_scenarios] >= 0)

    (
        branches_zero_break_points, branches_one_break_points, branches_two_break_points
    ) = branches_by_breakpoints(system)

    # Constraints Zero Break points
    @constraint(
        model,
        branch_flow_sl1_zero[m in branches_zero_break_points, t in datetimes, c in all_scenarios],
        sl1_fl[m, t, c] == 0
    )
    @constraint(
        model,
        branch_flow_sl2_zero[m in branches_zero_break_points, t in datetimes, c in all_scenarios],
        sl2_fl[m, t, c] == 0
    )
    # Constraints One Break Point
    @constraint(
        model,
        branch_flow_sl2_one[m in branches_one_break_points, t in datetimes, c in all_scenarios],
        sl2_fl[m, t, c] == 0
    )
    # Constraints Two Break Points Base Case
    @constraint(
        model,
        branch_flow_sl1_two_base[m in branches_two_break_points, t in datetimes, c in ["base_case"]],
        sl1_fl[m, t, c] <= (mon_branches[m].break_points[2]-mon_branches[m].break_points[1])*(mon_branches[m].rate_a/100)
    )
    # Constraints Two Break Points Contingency Scenarios
    @constraint(
        model,
        branch_flow_sl1_two_cont[m in branches_two_break_points, t in datetimes, c in contingencies],
        sl1_fl[m, t, c] <= (mon_branches[m].break_points[2]-mon_branches[m].break_points[1])*(mon_branches[m].rate_b/100)
    )
    # Add slacks penalties to the objective
    slack_cost = AffExpr()
    for m in branches_one_break_points, t in datetimes, c in all_scenarios
        add_to_expression!(slack_cost, sl1_fl[m, t, c] * mon_branches[m].penalties[1])
    end
    for m in branches_two_break_points, t in datetimes, c in all_scenarios
        add_to_expression!(slack_cost, sl1_fl[m, t, c] * mon_branches[m].penalties[1])
        add_to_expression!(slack_cost, sl2_fl[m, t, c] * mon_branches[m].penalties[2])
    end
    _add_to_objective!(model, slack_cost)
    return fnm
end

function latex(::typeof(con_thermal_branch!))
    join([
        latex(_con_nodal_net_injection_ed!)
        latex(_con_branch_flows!)
        latex(_con_branch_flow_limits!)
        latex(_con_branch_flow_slacks!)
    ], '\n')
end


"""
    con_thermal_branch!(fnm::FullNetworkModel)

Adds the nodal net injections, branch flows, and branch flow limits constraints for the case
base and the selected contingencyies to the full network model. The nodal net injection
is formulated different for the Unit Commitment and for the Economic Dispatch.

The constraints above are formulated as:

The Base Case Net Nodal Injection for the Economic Dispatch is formulated as:
$(latex(_con_nodal_net_injection_ed!))

The Base Case Net Nodal Injection for the Unit Commitment is formulated as:
$(latex(_con_nodal_net_injection_uc!))

Base Case and Contingency Branch Flows are formulated as:
$(latex(_con_branch_flows!))

Base Case and Contingency Branch Flows Limits are formulated as:
$(latex(_con_branch_flow_limits!))

The constraints are named `nodal_net_injection`, `branch_flows_base`, `branch_flows_conting`,
`branch_flow_max` (for the high boundary) and `branch_flow_min` (for the lower boundary) respectively.
"""
function con_thermal_branch!(fnm::FullNetworkModel; threshold=_SF_THRESHOLD)
    #Shared Data
    system = fnm.system
    bus_names = sort(keys(get_buses(system)))
    D = _keyed_to_dense(get_load_timeseries(system))
    unit_codes_perbus = get_gens_per_bus(system)
    load_names_perbus = get_loads_per_bus(system)

    mon_branches = filter(br -> br.is_monitored, get_branches(system))
    mon_branches_names = string.(collect(keys(mon_branches)))

    ptdf = sortkeys(get_ptdf(system), dims=2)
    _threshold!(ptdf)
    lodfs = get_lodf(system)
    insert!(
        lodfs,
        "base_case",
        KeyedArray(Matrix{Float64}(undef, 0, 0), (String[], String[]))
    )
    lodfs_converted = map(lodfs) do lodf
        _keyed_to_dense(lodf)
    end
    #lodfs = _add_base_case_to_lodfs(lodf_dict) # Add base case to the LODF Dictionary
    scenarios = collect(keys(lodfs)) # All scenarios (base case and contingency scenarios)
    branches_out_names = unique(vcat(axiskeys.(lodfs, 2)...))
    # The flows need to be defined only for the branches that are monitored or going
    # out under some contingency.
    branches_names_monitored_or_out = union(branches_out_names, mon_branches_names)
    #Add the nodal net injections for the base-case
    _con_nodal_net_injection!(fnm, bus_names, D, unit_codes_perbus, load_names_perbus)
    #Add the branch flows constraints for all scenarios
    _con_branch_flows!(
        fnm,
        mon_branches_names,
        branches_names_monitored_or_out,
        ptdf,
        lodfs_converted
    )
    _con_branch_flow_slacks!(
        fnm,
        mon_branches,
        mon_branches_names,
        scenarios,
    )
    _con_branch_flow_limits!(
        fnm,
        mon_branches,
        mon_branches_names,
        scenarios
    )
    return fnm
end

"Upper bound on generation + ancillary services"
function _con_ancillary_max!(model::Model, unit_codes, datetimes, Pmax, Pregmax, u, u_reg)
    p = model[:p]
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    # `u` here may be a variable or it may be the parameter "`U`". Likewise `u_reg`/`U_reg`.
    @constraint(
        model,
        ancillary_max[g in unit_codes, t in datetimes],
        p[g, t] + r_reg[g, t] + r_spin[g, t] + r_on_sup[g, t] <=
            Pmax[g, t] * (u[g, t] - u_reg[g, t]) + Pregmax[g, t] * u_reg[g, t]
    )
    return model
end

"Lower bound on generation - ancillary services"
function _con_ancillary_min!(model::Model, unit_codes, datetimes, Pmin, Pregmin, u, u_reg)
    p = model[:p]
    r_reg = model[:r_reg]
    # `u`/`u_reg` may be variables or parameters (which we'd usually write as `U`/`U_reg`).
    @constraint(
        model,
        ancillary_min[g in unit_codes, t in datetimes],
        p[g, t] - r_reg[g, t] >=
            Pmin[g, t] * (u[g, t] - u_reg[g, t]) + Pregmin[g, t] * u_reg[g, t]
    )
    return model
end

# For UC only, so `u_reg` should be a variable here.
"Upper bound on regulation"
function _con_regulation_max!(model::Model, unit_codes, datetimes, Pregmin, Pregmax, u_reg)
    r_reg = model[:r_reg]
    @constraint(
        model,
        regulation_max[g in unit_codes, t in datetimes],
        r_reg[g, t] <= 0.5 * (Pregmax[g, t] - Pregmin[g, t]) * u_reg[g, t]
    )
    return model
end

"Upper bound on spinning + online supplemental reserves"
function _con_spin_and_sup_max!(model::Model, unit_codes, datetimes, Pmin, Pmax, u)
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    # `u` may be a variable or a parameter (which we'd usually write as `U`).
    @constraint(
        model,
        spin_and_sup_max[g in unit_codes, t in datetimes],
        r_spin[g, t] + r_on_sup[g, t] <= (Pmax[g, t] - Pmin[g, t]) * u[g, t]
    )
    return model
end

"Upper bound on offline supplemental reserve"
function _con_off_sup_max!(model::Model, unit_codes, datetimes, Pmin, Pmax, u)
    r_off_sup = model[:r_off_sup]
    # `u` may be a variable or a parameter (which we'd usually write as `U`).
    @constraint(
        model,
        off_sup_max[g in unit_codes, t in datetimes],
        r_off_sup[g, t] <= (Pmax[g, t] - Pmin[g, t]) * (1 - u[g, t])
    )
    return model
end

"Ensure that units that don't provide services have services set to zero."
function _con_zero_non_providers!(model::Model, system::System, unit_codes, datetimes)
    # Units that provide each service
    reg_providers = get_regulation_providers(system)
    spin_providers = get_spinning_providers(system)
    on_sup_providers = get_sup_on_providers(system)
    off_sup_providers = get_sup_off_providers(system)
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    @constraint(
        model,
        zero_reg[g in setdiff(Set(unit_codes), reg_providers), t in datetimes],
        r_reg[g, t] == 0
    )
    @constraint(
        model,
        zero_spin[g in setdiff(Set(unit_codes), spin_providers), t in datetimes],
        r_spin[g, t] == 0
    )
    @constraint(
        model,
        zero_on_sup[g in setdiff(Set(unit_codes), on_sup_providers), t in datetimes],
        r_on_sup[g, t] == 0
    )
    @constraint(
        model,
        zero_off_sup[g in setdiff(Set(unit_codes), off_sup_providers), t in datetimes],
        r_off_sup[g, t] == 0
    )
    return model
end

# For UC, add additional `zero_u_reg` constraint. `u_reg` here should be a variable.
function _con_zero_non_providers!(model::Model, system::System, unit_codes, datetimes, u_reg)
    reg_providers = get_regulation_providers(system)
    non_providers = setdiff(Set(unit_codes), reg_providers)
    @constraint(
        model,
        zero_u_reg[g in non_providers, t in datetimes],
        u_reg[g, t] == 0
    )
    return _con_zero_non_providers!(model, system, unit_codes, datetimes)
end

"""
    con_ancillary_ramp_rates!(fnm::FullNetworkModel)

Adds ancillary service ramp rate constraints to the full network model.

$(latex(con_ancillary_ramp_rates!))

The constraints are named `ramp_regulation` and `ramp_spin_sup`.
"""
function con_ancillary_ramp_rates!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    generators = get_generators(system)
    unit_codes = keys(generators)
    # Get ramp rates in pu/min
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    # Allocated regulation can't be over 5 minutes of ramping
    @constraint(
        model,
        ramp_regulation[g in unit_codes, t in datetimes],
        r_reg[g, t] <= 5 * generators[g].ramp_up
    )
    # Allocated reserves can't be over 10 minutes of ramping
    @constraint(
        model,
        ramp_spin_sup[g in unit_codes, t in datetimes],
        r_spin[g, t] + r_on_sup[g, t] + r_off_sup[g, t] <= 10 * generators[g].ramp_up
    )
    return fnm
end

"""
    con_generation_ramp_rates!(fnm::FullNetworkModel; slack=nothing)

Adds generation ramp rate constraints to the full network model.

$(latex(con_generation_ramp_rates!))

The constraints are named `ramp_up`, `ramp_up_initial`, `ramp_down`, and `ramp_down_initial`.
"""
function con_generation_ramp_rates!(fnm::FullNetworkModel; slack=nothing)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    generators = get_generators(system)
    unit_codes = keys(generators)

    P0 = _keyed_to_dense(get_initial_generation(system))
    Pmax = _keyed_to_dense(get_pmax_timeseries(system))
    U0 = _keyed_to_dense(get_initial_commitment(system))
    Δt = Dates.value(Minute(first(diff(datetimes))))
    Δh = Hour(Δt / 60) # assume hourly resolution
    h1 = first(datetimes)
    # We only consider the initial ramp for the units available in the first hour.
    # This is done to avoid situations where a unit has initial generation coming from the
    # previous day, but is marked as unavailable in hour 1, which leads to infeasibility
    # because it cannot ramp down to zero.
    A = _keyed_to_dense(get_availability_timeseries(system))
    units_available_in_first_hour = @views axes(A, 1)[A.data[:, 1] .== 1]

    p = model[:p]
    u = model[:u]
    v = model[:v]
    w = model[:w]
    # Ramp up - generation can't go up more than the ramp capacity (defined in pu/min)
    @constraint(
        model,
        ramp_up[g in unit_codes, t in datetimes[2:end]],
        p[g, t] - p[g, t - Δh] <= Δt * generators[g].ramp_up * u[g, t - Δh] + generators[g].startup_cost * v[g, t]
    )
    @constraint(
        model,
        ramp_up_initial[g in units_available_in_first_hour],
        p[g, h1] - P0[g] <= Δt * generators[g].ramp_up * U0[g] + generators[g].startup_cost * v[g, h1]
    )
    # Ramp down - generation can't go down more than ramp capacity (defined in pu/min).
    # We consider SU = SD.
    # NB: we do not enforce the ramp down rate whenever there is a change in generator
    # availability. The reason is that changes in generator availability plus the fact that
    # we use approximate ramp rates can easily lead to infeasibility. Example: consider
    # a unit that has initial generation of 4*60*RR (i.e. 4 times the hourly ramp rate)
    # and is unavailable in hour 3. This means it is impossible for the unit to ramp down
    # that amount in 3 hours, leading to infeasibility. Therefore, whenever A_{g,t} is 0,
    # the constraint is relaxed by allowing the unit to ramp as much as it wants.
    @constraint(
        model,
        ramp_down[g in unit_codes, t in datetimes[2:end]],
        p[g, t - Δh] - p[g, t] <=
            Δt * generators[g].ramp_up * u[g, t] + generators[g].startup_cost * w[g, t] + (1 - A[g, t]) * Pmax[g, t - Δh]
    )
    @constraint(
        model,
        ramp_down_initial[g in units_available_in_first_hour],
        P0[g] - p[g, h1] <= Δt * generators[g].ramp_up * u[g, h1] + generators[g].startup_cost * w[g, h1]
    )

    # If the constraints are supposed to be soft constraints, add slacks
    if slack !== nothing
        @variable(model, sl_ramp[g in unit_codes, t in datetimes] >= 0)
        for g in unit_codes
            for t in datetimes[2:end]
                set_normalized_coefficient(ramp_up[g, t], sl_ramp[g, t], -1.0)
                set_normalized_coefficient(ramp_down[g, t], sl_ramp[g, t], -1.0)
            end
        end
        for g in units_available_in_first_hour
            set_normalized_coefficient(ramp_up_initial[g], sl_ramp[g, h1], -1.0)
            set_normalized_coefficient(ramp_down_initial[g], sl_ramp[g, h1], -1.0)
        end

        # Add slack penalty to the objective
        slack_cost = AffExpr()
        for g in units_available_in_first_hour
            add_to_expression!(slack_cost, slack * sl_ramp[g, h1])
        end
        for g in unit_codes, t in datetimes[2:end]
            add_to_expression!(slack_cost, slack * sl_ramp[g, t])
        end
        _add_to_objective!(model, slack_cost)
    end

    return fnm
end

function latex(::typeof(con_must_run!))
    return """
        ``u_{g, t} \\geq MR_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    con_must_run!(fnm::FullNetworkModel)

Ensure that the units with must run flag set to 1 are committed.

$(latex(con_must_run!))

The constraint is named `must_run`.
"""
function con_must_run!(fnm::FullNetworkModel)
    unit_codes = keys(get_generators(fnm.system))
    MR = _keyed_to_dense(get_must_run_timeseries(fnm.system))
    u = fnm.model[:u]
    # We constrain the commitment variable to be >= the must run flag, this way if the flag
    # is zero it has no impact, and if it is 1 it forces the commitment to be 1.
    @constraint(
        fnm.model, must_run[g in unit_codes, t in fnm.datetimes], u[g, t] >= MR[g, t]
    )
    return fnm
end

function latex(::typeof(con_availability!))
    return """
        ``u_{g, t} \\leq A_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    con_availability!(fnm::FullNetworkModel)

Ensure that unavailable units cannot be committed; units that are available may or may not be.

$(latex(con_availability!))

The constraint is named `availability`.
"""
function con_availability!(fnm::FullNetworkModel)
    unit_codes = keys(get_generators(fnm.system))
    A = _keyed_to_dense(get_availability_timeseries(fnm.system))
    u = fnm.model[:u]
    # We constrain the commitment variable to be <= the availability flag, this way if the
    # unit is unavailable it cannot be committed, and if it is available there is no impact.
    @constraint(
        fnm.model, availability[g in unit_codes, t in fnm.datetimes], u[g, t] <= A[g, t]
    )
    return fnm
end
