"""
    economic_dispatch(
        system::System, solver, datetimes=get_forecast_timestamps(system); slack=1e4
    ) -> FullNetworkModel{ED}

Defines the economic dispatch default template.
Receives a `system` from FullNetworkDataPrep and returns a `FullNetworkModel` with a
`model` with the following formulation:

$(_write_formulation(
    objectives=[
        latex(_obj_thermal_variable_cost!),
        latex(obj_ancillary_costs!),
    ],
    constraints=[
        latex(_var_thermal_gen_blocks_ed!),
        latex(_con_generation_limits_ed!),
        latex(con_ancillary_limits_ed!),
        latex(con_regulation_requirements!),
        latex(con_operating_reserve_requirements!),
        latex(con_energy_balance_ed!),
    ],
    variables=[
        latex(var_thermal_generation!),
        latex(_var_ancillary_services!),
    ]
))

Real Time Formulation includes ramp rates constraints for intervals of 5 and 10 min, these
ones are not being considerded since this ED approach is solved hourly. Thus its highly
likely that these constraints are not binding within the hourly time period.

Thermal branch flow limits are not considered in this formulation.

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

Keyword arguments:
 - `slack=1e4`: The slack penalty for the soft constraints.

"""
function economic_dispatch(
    system::System, solver, datetimes=get_forecast_timestamps(system); slack = 1e4
)
    # Initialize FNM
    fnm = FullNetworkModel{ED}(system, datetimes)
    # Variables
    var_thermal_generation!(fnm)
    var_ancillary_services!(fnm)
    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm; slack)
    con_operating_reserve_requirements!(fnm; slack)
    con_energy_balance!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_ancillary_costs!(fnm)

    set_optimizer(fnm, solver)
    return fnm
end

"""
    economic_dispatch_branch_flow_limits(
        system::System, datetimes=get_forecast_timestamps(system); slack=1e4
    ) -> FullNetworkModel{ED}

Defines the economic dispatch template with base case thermal branch constraints.
Receives a `system` from FullNetworkDataPrep and returns a `FullNetworkModel` with a
`model` with the following formulation:

$(_write_formulation(
    objectives=[
        latex(_obj_thermal_variable_cost!),
        latex(obj_ancillary_costs!),
    ],
    constraints=[
        latex(_var_thermal_gen_blocks_ed!),
        latex(_con_generation_limits_ed!),
        latex(con_ancillary_limits_ed!),
        latex(con_regulation_requirements!),
        latex(con_operating_reserve_requirements!),
        latex(con_energy_balance_ed!),
        latex(_con_nodal_net_injection_ed!),
        latex(_con_branch_flows!),
        latex(_con_branch_flow_limits!),
        latex(_con_branch_flow_slacks!)
    ],
    variables=[
        latex(var_thermal_generation!),
        latex(_var_ancillary_services!),
    ]
))

Real Time Formulation includes ramp rates constraints for intervals of 5 and 10 min, these
ones are not being considerded since this ED approach is solved hourly. Thus its highly
likely that these constraints are not binding within the hourly time period.

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

Keyword arguments:
 - `slack=1e4`: The slack penalty for the soft constraints.
"""
function economic_dispatch_branch_flow_limits(
    system::System, solver, datetimes=get_forecast_timestamps(system); slack = 1e4
)
    # Initialize FNM
    fnm = FullNetworkModel{ED}(system, datetimes)
    # Variables
    var_thermal_generation!(fnm)
    var_ancillary_services!(fnm)
    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm; slack)
    con_operating_reserve_requirements!(fnm; slack)
    con_energy_balance!(fnm)
    con_thermal_branch!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_ancillary_costs!(fnm)

    set_optimizer(fnm, solver)
    return fnm
end
