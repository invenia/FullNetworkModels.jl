"""
    unit_commitment(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        relax_integrality=false
    ) -> FullNetworkModel

Defines the unit commitment default template.
Receives a `system` from FullNetworkDataPrep and returns a `FullNetworkModel` with a
`model` with the following formulation:

$(_write_formulation(
    objectives=[
        _latex(_obj_thermal_variable_cost!),
        _latex(obj_thermal_noload_cost!),
        _latex(obj_thermal_startup_cost!),
        _latex(obj_ancillary_costs!),
        _latex(_obj_bid_variable_cost!),
    ],
    constraints=[
        _latex(_var_thermal_gen_blocks_uc!),
        _latex(_con_generation_limits_uc!),
        _latex(_con_startup_shutdown!),
        _latex(con_ancillary_limits_uc!),
        _latex(con_regulation_requirements!),
        _latex(con_operating_reserve_requirements!),
        _latex(_con_ancillary_services!),
        _latex(con_ramp_rates!),
        _latex(con_energy_balance_uc!),
        _latex(_var_bid_blocks!),
    ],
    variables=[
        _latex(var_thermal_generation!),
        _latex(var_commitment!),
        _latex(_var_startup_shutdown!),
        _latex(_var_ancillary_services!),
        _latex(var_bids!),
    ]
))

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

Keyword arguments:
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function unit_commitment(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    relax_integrality=false
)
    # Initialize FNM
    fnm = FullNetworkModel{UC}(system, solver, datetimes)
    # Variables
    var_thermal_generation!(fnm)
    var_commitment!(fnm)
    var_startup_shutdown!(fnm)
    var_ancillary_services!(fnm)
    var_bids!(fnm)
    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm)
    con_operating_reserve_requirements!(fnm)
    con_ramp_rates!(fnm)
    con_energy_balance!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_thermal_startup_cost!(fnm)
    obj_ancillary_costs!(fnm)
    obj_bids!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    return fnm
end

"""
    unit_commitment_soft_ramps(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        slack=1e4, relax_integrality=false
    ) -> FullNetworkModel

Defines the unit commitment template with soft generation ramp constraints.
Receives a `system` from FullNetworkDataPrep and returns a `FullNetworkModel` with a
`model` with the same formulation as `unit_commitment`, except for the ramp constraints,
which are modeled as soft constraints with slack variables.

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

Keyword arguments:
 - `slack=1e4`: The slack penalty for the soft constraints.
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function unit_commitment_soft_ramps(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    slack=1e4, relax_integrality=false
)
    # Initialize FNM
    fnm = FullNetworkModel{UC}(system, solver, datetimes)
    # Variables
    var_thermal_generation!(fnm)
    var_commitment!(fnm)
    var_startup_shutdown!(fnm)
    var_ancillary_services!(fnm)
    var_bids!(fnm)
    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm)
    con_operating_reserve_requirements!(fnm)
    con_ramp_rates!(fnm; slack=slack)
    con_energy_balance!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_thermal_startup_cost!(fnm)
    obj_ancillary_costs!(fnm)
    obj_bids!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    return fnm
end

"""
    unit_commitment_no_ramps(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        relax_integrality=false
    ) -> FullNetworkModel

Defines the unit commitment template with no ramp constraints.
Receives a `system` from FullNetworkDataPrep and returns a `FullNetworkModel` with a
`model` with the same formulation as `unit_commitment`, except for ramp constraints, which
are omitted.

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

Keyword arguments:
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function unit_commitment_no_ramps(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    relax_integrality=false
)
    # Initialize FNM
    fnm = FullNetworkModel{UC}(system, solver, datetimes)
    # Variables
    var_thermal_generation!(fnm)
    var_commitment!(fnm)
    var_startup_shutdown!(fnm)
    var_ancillary_services!(fnm)
    var_bids!(fnm)
    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm)
    con_operating_reserve_requirements!(fnm)
    con_energy_balance!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_thermal_startup_cost!(fnm)
    obj_ancillary_costs!(fnm)
    obj_bids!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    return fnm
end
