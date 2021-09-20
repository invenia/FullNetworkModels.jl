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
    unit_codes = get_unit_codes(ThermalGen, system)
    Pmin = get_pmin(system, datetimes)
    Pmax = get_pmax(system, datetimes)

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
    unit_codes = get_unit_codes(ThermalGen, system)
    U = get_commitment_status(system, datetimes)
    Pmin = get_pmin(system, datetimes)
    Pmax = get_pmax(system, datetimes)

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
    unit_codes = get_unit_codes(ThermalGen, system)
    Pmax = get_pmax(system, datetimes)
    Pregmax = get_regmax(system, datetimes)
    Pmin = get_pmin(system, datetimes)
    Pregmin = get_regmin(system, datetimes)

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
    unit_codes = get_unit_codes(ThermalGen, system)
    Pmax = get_pmax(system, datetimes)
    Pregmax = get_regmax(system, datetimes)
    Pmin = get_pmin(system, datetimes)
    Pregmin = get_regmin(system, datetimes)
    U = get_commitment_status(system, datetimes)
    U_reg = get_commitment_reg_status(system, datetimes)

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
    - For `fnm::FullNetworkModel{<:ED}` this defaults to a soft constraint (`slack=1e4`).
    - For `fnm::FullNetworkModel{<:UC}` this defaults to a hard constraint (`slack=nothing`).
"""
function con_regulation_requirements!(fnm::FullNetworkModel{<:UC}; slack=nothing)
    return con_regulation_requirements!(fnm, slack)
end

function con_regulation_requirements!(fnm::FullNetworkModel{<:ED}; slack=1e4)
    return con_regulation_requirements!(fnm, slack)
end

function con_regulation_requirements!(fnm::FullNetworkModel, slack)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    reserve_zones = get_reserve_zones(system)
    zone_gens = _generators_by_reserve_zone(system)
    reg_requirements = get_regulation_requirements(system)
    r_reg = model[:r_reg]
    @constraint(
        model,
        regulation_requirements[z in reserve_zones, t in datetimes],
        sum(r_reg[g, t] for g in zone_gens[z]) >= reg_requirements[z]
    )
    if slack !== nothing
        # Soft constraints, add slacks
        @variable(model, Γ_reg_req[z in reserve_zones, t in datetimes] >= 0)
        for z in reserve_zones, t in datetimes
            set_normalized_coefficient(regulation_requirements[z, t], Γ_reg_req[z, t], 1.0)
            # Add slack penalty to the objective
            set_objective_coefficient(model, Γ_reg_req[z, t], slack)
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

function con_operating_reserve_requirements!(fnm::FullNetworkModel{<:ED}; slack=1e4)
    return con_operating_reserve_requirements!(fnm, slack)
end

function con_operating_reserve_requirements!(fnm::FullNetworkModel, slack)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    reserve_zones = get_reserve_zones(system)
    zone_gens = _generators_by_reserve_zone(system)
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
        @variable(model, Γ_or_req[z in reserve_zones, t in datetimes] >= 0)
        for z in reserve_zones, t in datetimes
            set_normalized_coefficient(operating_reserve_requirements[z, t], Γ_or_req[z, t], 1.0)
            # Add slack penalty to the objective
            set_objective_coefficient(model, Γ_or_req[z, t], slack)
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
        ``p_{g, 1} - P^{0}_{g} \\leq \\Delta t RR_{g} U^{0}_{g} + SU_{g} v_{g, 1}, \\forall g \\in \\mathcal{G}`` \n
        ``p_{g, t - 1} - p_{g, t} \\leq \\Delta t RR_{g} u_{g, t} + SD_{g} w_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T} \\setminus \\{1\\}`` \n
        ``P^{0}_{g} - p_{g, 1} \\leq \\Delta t RR_{g} u_{g, 1} + SD_{g} w_{g, 1}, \\forall g \\in \\mathcal{G}``
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
function con_energy_balance!(fnm::FullNetworkModel{<:ED})
    model = fnm.model
    system = fnm.system
    unit_codes = get_unit_codes(ThermalGen, system)
    load_names = get_load_names(PowerLoad, system)
    D = get_fixed_loads(system)
    p = model[:p]
    @constraint(
        model,
        energy_balance[t in fnm.datetimes],
        sum(p[g, t] for g in unit_codes) == sum(D[f, t] for f in load_names)
    )
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
function con_energy_balance!(fnm::FullNetworkModel{<:UC})
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    unit_codes = get_unit_codes(ThermalGen, system)
    load_names = get_load_names(PowerLoad, system)
    inc_names = get_bid_names(Increment, system)
    dec_names = get_bid_names(Decrement, system)
    psd_names = get_bid_names(PriceSensitiveDemand, system)
    D = get_fixed_loads(system, datetimes)
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
    return fnm
end

function latex(::typeof(_con_nodal_net_injection_ed!))
    return """
        ``p^{net}_{n, t} = \\sum_{g \\in \\mathcal{G}_n} p_{g, t} +
        \\sum_{f \\in \\mathcal{F}_n} D_{f, t}, \\forall n \\in \\mathcal{V}, t \\in \\mathcal{T}``
        """
end
function latex(::typeof(_con_nodal_net_injection_uc!))
    return """
        ``p^{net}_{n, t} = \\sum_{g \\in \\mathcal{G_n}} p_{g, t} + \\sum_{i \\in \\mathcal{I}_n} inc_{i, t}
        - \\sum_{f \\in \\mathcal{F}_n} D_{f, t} - \\sum_{d \\in \\mathcal{D}_n} dec_{d, t}
        - \\sum_{s \\in \\mathcal{S}_n} psd_{s, t}, \\forall n \\in \\mathcal{V}, t \\in \\mathcal{T}``
        """
end

"""
    _con_nodal_net_injection!(fnm::FullNetworkModel{ED}, bus_numbers, D, unit_codes_perbus, load_names_perbus)

Adds the Net Nodal Injection constraints to the full network model. The constraints calculate
the net injection per node for all the buses of the system.

The Net Nodal Injection for the Economic Dispatch is formulated as:

$(latex(_con_nodal_net_injection_ed!))

The constraint is named `nodal_net_injection`.
"""
function _con_nodal_net_injection!(fnm::FullNetworkModel{<:ED}, bus_numbers, D, unit_codes_perbus, load_names_perbus)
    model = fnm.model
    @variable(model, p_net[n in bus_numbers, t in fnm.datetimes])
    p = model[:p]
    p_net = model[:p_net]
    @constraint(
        model,
        nodal_net_injection[n in bus_numbers, t in fnm.datetimes],
        p_net[n, t] ==
            sum(p[g, t] for g in unit_codes_perbus[n]) -
            sum(D[f, t] for f in load_names_perbus[n])
    )
    return fnm
end

"""
_con_nodal_net_injection!(fnm::FullNetworkModel{UC}, bus_numbers, D, unit_codes_perbus, load_names_perbus)

Adds the Net Nodal Injection constraints to the full network model. The constraints calculate
the net injection per node for all the buses of the system.

The Net Nodal Injection for the Unit Commitment is formulated as:

$(latex(_con_nodal_net_injection_uc!))

The constraint is named `nodal_net_injection`.
"""
function _con_nodal_net_injection!(fnm::FullNetworkModel{<:UC}, bus_numbers, D, unit_codes_perbus, load_names_perbus)
    model = fnm.model
    system = fnm.system
    inc_names_perbus = get_bid_names_perbus(Increment, system)
    dec_names_perbus = get_bid_names_perbus(Decrement, system)
    psd_names_perbus = get_bid_names_perbus(PriceSensitiveDemand, system)
    @variable(model, p_net[n in bus_numbers, t in fnm.datetimes])
    p = model[:p]
    p_net = model[:p_net]
    inc = model[:inc]
    dec = model[:dec]
    psd = model[:psd]
    @constraint(
        model,
        nodal_net_injection[n in bus_numbers, t in fnm.datetimes],
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
        ``fl^{0}_{m, t} = \\sum_{n \\in \\mathcal{N}_m} PTDF_{m, n} p^{net}_{n, t},
        \\forall m \\in \\mathcal{M}_0, t \\in \\mathcal{T}``
        """
end

"""
    _con_branch_flows!(fnm::FullNetworkModel, bus_numbers, mon_branches_names, sys_ptdf)

Adds the branch power flow constraints to the full network model. The constraints calculates
the power flow trough the "m" monitored Lines and transformers.

The branch power flows are calculated as:

$(latex(_con_branch_flows!))

The constraint is named `branch_flows`.
"""
function _con_branch_flows!(fnm::FullNetworkModel, bus_numbers, mon_branches_names, sys_ptdf)
    model = fnm.model
    @variable(model, fl0[m in mon_branches_names, t in fnm.datetimes])
    p_net = model[:p_net]
    @constraint(
        model,
        branch_flows[m in mon_branches_names, t in fnm.datetimes],
        fl0[m, t] == sum(sys_ptdf[m, n] * p_net[n, t] for n in bus_numbers)
    )
    return fnm
end

function latex(::typeof(_con_branch_flow_limits!))
    return """
        ``-FL^{rate_a}_{m, t} -sl1^{fl0}_{m, t} -sl2^{fl0}_{m, t} <= fl^0_{m, t} <= FL^{rate_a}_{m, t} +sl1^{fl0}_{m, t} +sl2^{fl0}_{m, t}``
        """
end

"""
    _con_branch_flow_limits!(fnm::FullNetworkModel, mon_branches_names, mon_branches_rates)

Adds the thermal branch constraints to the full network model. The constraints ensure that
the power flow trough the "m" monitored lines and transformers is smaller than the
transmission limit in both directions (Power flowing from bus "i" to bus "j" and from bus
"j" to bus "i").

The thermal branch constraint is formulated as:

$(latex(_con_branch_flow_limits!))

The constraint is named `branch_flow_max` for the high boundary and `branch_flow_min`
for the lower boundary.
"""
function _con_branch_flow_limits!(fnm::FullNetworkModel, mon_branches_names, mon_branches_rates)
    model = fnm.model
    p = model[:p]
    fl0 = model[:fl0]
    sl1_fl0 = model[:sl1_fl0]
    sl2_fl0 = model[:sl2_fl0]
    @constraint(
        model,
        branch_flow_max[m in mon_branches_names, t in fnm.datetimes],
        fl0[m, t] <= mon_branches_rates[m] + sl1_fl0[m, t] + sl2_fl0[m, t]
    )
    @constraint(
        model,
        branch_flow_min[m in mon_branches_names, t in fnm.datetimes],
        fl0[m, t] >= - mon_branches_rates[m] - sl1_fl0[m, t] - sl2_fl0[m, t]
    )
    return fnm
end

function latex(::typeof(_con_branch_flow_slacks!))
    return """
    ``0 <= sl1^{fl0}_{m, t} <= \\bar{SL1}^{fl0}_{m, t}`` \n
    ``0 <= sl2^{fl0}_{m, t}``
    """
end
"""
    _con_branch_flow_slacks!(fnm::FullNetworkModel, mon_branches_names, mon_branches_rates)

Adds the power flow slack penalty constraints to the full network model. The constraints
ensure that the power flow trough the "m" monitored lines and transformers is penalised
according to the branch breaking points and penalties.

The power flow slack penalty constraints are formulated as:

$(latex(_con_branch_flow_slacks!))

The Breakpoints are the percentage value of the Branch Rate in which the penalty for branch
flow changes. A branch could have one, two or no breakpoints. For example a Branch of 75MW
rate (FL) with one breakpoint at [100%] of the line rate will have a corresponding penalty
"Penalty1 for any flow avobe 100% (75MW). For a branch with two breakpoints [100%, 110%] will
have a penalty "Penalty1" for any flow in betweeen 100% (75MW) and 110% (82.5MW), and for any
MW avobe the 110% of the branch rate, the penalty will be "Penalty2". Finally a branch with no
breakpoints, the constraint should be a hard constraint. Thus, the slacks for each case should
be:

No breakpoints:
sl1^{fl0}_{m, t} = 0
sl2^{fl0}_{m, t} = 0

One breakpoints:
sl1^{fl0}_{m, t} = 0
0 <= sl2^{fl0}_{m, t}

Two breakpoints:
0 <= sl1^{fl0}_{m, t} <= (110% - 100%)*75MW/(100*Sbase)
0 <= sl2^{fl0}_{m, t}

The constraint is named `branch_flow_sl1` for the first step slack and `branch_flow_sl2`
for the second step slack.
"""
function _con_branch_flow_slacks!(
        fnm::FullNetworkModel,
        mon_branches_names,
        mon_branches_rates,
        mon_branches_break_points,
        mon_branches_penalties
    )

    model = fnm.model
    datetimes = fnm.datetimes
    # Slacks
    @variable(model, sl1_fl0[m in mon_branches_names, t in datetimes] >= 0)
    @variable(model, sl2_fl0[m in mon_branches_names, t in datetimes] >= 0)

    (branches_zero_break_points,
    branches_one_break_points,
    branches_two_break_points) = get_branches_num_break_points(Branch, system)

    # Constraints Zero Break points
    @constraint(
        model,
        branch_flow_sl1[m in branches_zero_break_points, t in datetimes],
        sl1_fl0[m, t] == 0
    )
    @constraint(
        model,
        branch_flow_sl2[m in branches_zero_break_points, t in datetimes],
        sl2_fl0[m, t] == 0
    )
    # Constraints One Break Point
    @constraint(
        model,
        branch_flow_sl1[m in branches_one_break_points, t in datetimes],
        sl1_fl0[m, t] == 0
    )
    @constraint(
        model,
        branch_flow_sl2[m in branches_one_break_points, t in datetimes],
        0 <= sl2_fl0[m, t]
    )
    # Constraints Two Break Points
    @constraint(
        model,
        branch_flow_sl1[m in branches_two_break_points, t in datetimes],
        sl1_fl0[m, t] <= (mon_branches_break_points[m][2]-mon_branches_break_points[m][1])*(mon_branches_rates[m]/100)
    )
    @constraint(
        model,
        branch_flow_sl2[m in branches_two_break_points, t in datetimes],
        0 <= sl2_fl0[m, t]
    )
    for m in mon_branches_names, t in datetimes
        set_normalized_coefficient(branch_flow_sl1[m, t], sl1_fl0[m, t], 1.0)
        set_normalized_coefficient(branch_flow_sl2[m, t], sl2_fl0[m, t], 1.0)
        # Add slack penalty to the objective
        set_objective_coefficient(model, sl1_fl0[m, t], mon_branches_penalties[m][1])
        set_objective_coefficient(model, sl2_fl0[m, t], mon_branches_penalties[m][2])
    end
    return fnm
end

"""
    con_thermal_branch!(fnm::FullNetworkModel, sys_ptdf)

Adds the nodal net injections, branch flows, and branch flow limits constraints to the full
model. The nodal net injection is formulated different for the Unit Commitment and for the
Economic Dispatch.

The constraints avobe are formulated as:

The Net Nodal Injection for the Economic Dispatch is formulated as:
$(latex(_con_nodal_net_injection_ed!))

The Net Nodal Injection for the Unit Commitment is formulated as:
$(latex(_con_nodal_net_injection_uc!))

Branch Flows are formulated as:
$(latex(_con_branch_flows!))

Branch Flows Limits are formulated as:
$(latex(_con_branch_flow_limits!))

The constraints are named `nodal_net_injection`, `branch_flows`, `branch_flow_max` (for the
high boundary) and `branch_flow_min` (for the lower boundary) respectively.
"""
function con_thermal_branch!(fnm::FullNetworkModel, sys_ptdf)
    #Shared Data
    system = fnm.system
    bus_numbers = get_bus_numbers(system)
    D = get_fixed_loads(system)
    unit_codes_perbus = get_unit_codes_perbus(ThermalStandard, system)
    load_names_perbus = get_load_names_perbus(PowerLoad, system)
    mon_branches_names = get_monitored_branch_names(Branch, system)
    mon_branches_rates = get_branch_rates(mon_branches_names, system)
    mon_branches_break_points = get_branch_break_points(mon_branches_names, system)
    mon_branches_penalties = get_branch_penalties(mon_branches_names, system)
    #Add Constraints
    _con_nodal_net_injection!(fnm, bus_numbers, D, unit_codes_perbus, load_names_perbus)
    _con_branch_flows!(fnm, bus_numbers, mon_branches_names, sys_ptdf)
    _con_branch_flow_slacks!(
        fnm,
        mon_branches_names,
        mon_branches_rates,
        mon_branches_break_points,
        mon_branches_penalties
    )
    _con_branch_flow_limits!(fnm, mon_branches_names, mon_branches_rates)
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
function _con_ancillary_min!(model::Model, unit_codes, datetimes, Pmin, Pregmin, u ,u_reg)
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
    on_sup_providers = get_on_sup_providers(system)
    off_sup_providers = get_off_sup_providers(system)
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    @constraint(
        model,
        zero_reg[g in setdiff(unit_codes, reg_providers), t in datetimes],
        r_reg[g, t] == 0
    )
    @constraint(
        model,
        zero_spin[g in setdiff(unit_codes, spin_providers), t in datetimes],
        r_spin[g, t] == 0
    )
    @constraint(
        model,
        zero_on_sup[g in setdiff(unit_codes, on_sup_providers), t in datetimes],
        r_on_sup[g, t] == 0
    )
    @constraint(
        model,
        zero_off_sup[g in setdiff(unit_codes, off_sup_providers), t in datetimes],
        r_off_sup[g, t] == 0
    )
    return model
end

# For UC, add additional `zero_u_reg` constraint. `u_reg` here should be a variable.
function _con_zero_non_providers!(model::Model, system::System, unit_codes, datetimes, u_reg)
    reg_providers = get_regulation_providers(system)
    @constraint(
        model,
        zero_u_reg[g in setdiff(unit_codes, reg_providers), t in datetimes],
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
    unit_codes = get_unit_codes(ThermalGen, system)
    # Get ramp rates in pu/min
    RR = get_ramp_rates(system)
    r_reg = model[:r_reg]
    r_spin = model[:r_spin]
    r_on_sup = model[:r_on_sup]
    r_off_sup = model[:r_off_sup]
    # Allocated regulation can't be over 5 minutes of ramping
    @constraint(
        model,
        ramp_regulation[g in unit_codes, t in datetimes],
        r_reg[g, t] <= 5 * RR[g]
    )
    # Allocated reserves can't be over 10 minutes of ramping
    @constraint(
        model,
        ramp_spin_sup[g in unit_codes, t in datetimes],
        r_spin[g, t] + r_on_sup[g, t] + r_off_sup[g, t] <= 10 * RR[g]
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
    unit_codes = get_unit_codes(ThermalGen, system)
    RR = get_ramp_rates(system)
    SU = get_startup_limits(system)
    P0 = get_initial_generation(system)
    U0 = get_initial_commitment(system)
    Δt = _get_resolution_in_minutes(system)
    Δh = Hour(Δt / 60) # assume hourly resolution
    h1 = first(datetimes)
    p = model[:p]
    u = model[:u]
    v = model[:v]
    w = model[:w]
    # Ramp up - generation can't go up more than the ramp capacity (defined in pu/min)
    @constraint(
        model,
        ramp_up[g in unit_codes, t in datetimes[2:end]],
        p[g, t] - p[g, t - Δh] <= Δt * RR[g] * u[g, t - Δh] + SU[g, t] * v[g, t]
    )
    @constraint(
        model,
        ramp_up_initial[g in unit_codes],
        p[g, h1] - P0[g] <= Δt * RR[g] * U0[g] + SU[g, h1] * v[g, h1]
    )
    # Ramp down - generation can't go down more than ramp capacity (defined in pu/min)
    # We consider SU = SD
    @constraint(
        model,
        ramp_down[g in unit_codes, t in datetimes[2:end]],
        p[g, t - Δh] - p[g, t] <= Δt * RR[g] * u[g, t] + SU[g, t] * w[g, t]
    )
    @constraint(
        model,
        ramp_down_initial[g in unit_codes],
        P0[g] - p[g, h1] <= Δt * RR[g] * u[g, h1] + SU[g, h1] * w[g, h1]
    )

    # If the constraints are supposed to be soft constraints, add slacks
    if slack !== nothing
        @variable(model, Γ_ramp[g in unit_codes, t in datetimes] >= 0)
        for g in unit_codes
            set_normalized_coefficient(ramp_up_initial[g], Γ_ramp[g, h1], -1.0)
            set_normalized_coefficient(ramp_down_initial[g], Γ_ramp[g, h1], -1.0)
            for t in datetimes[2:end]
                set_normalized_coefficient(ramp_up[g, t], Γ_ramp[g, t], -1.0)
                set_normalized_coefficient(ramp_down[g, t], Γ_ramp[g, t], -1.0)
            end
        end

        # Add slack penalty to the objective
        for g in unit_codes, t in datetimes
            set_objective_coefficient(model, Γ_ramp[g, t], slack)
        end
    end

    return fnm
end
