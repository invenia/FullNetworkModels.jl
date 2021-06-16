"""
    unit_commitment(
        system::System, solver; soft=false, relax_integrality=false
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
    ],
    constraints=[
        _latex(_var_thermal_gen_blocks!; commitment=true),
        _latex(con_generation_limits!; commitment=true),
        _latex(_con_startup_shutdown!),
        _latex(con_ancillary_limits!),
        _latex(con_regulation_requirements!),
        _latex(con_operating_reserve_requirements!),
        _latex(_con_ancillary_services!),
        _latex(con_ramp_rates!),
        _latex(con_energy_balance!),
    ],
    variables=[
        _latex(var_thermal_generation!),
        _latex(var_commitment!),
        _latex(_var_startup_shutdown!),
        _latex(_var_ancillary_services!),
    ]
))

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.

Keyword arguments:
 - `soft=false`: If set to `true`, soft constraints will be used (e.g. ramps).
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function unit_commitment(system::System, solver; soft=false, relax_integrality=false)
    # Initialize FNM
    fnm = FullNetworkModel(system, solver)
    # Variables
    var_thermal_generation!(fnm)
    var_commitment!(fnm)
    var_startup_shutdown!(fnm)
    var_ancillary_services!(fnm)
    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm)
    con_operating_reserve_requirements!(fnm)
    con_ramp_rates!(fnm; soft=soft)
    con_energy_balance!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_thermal_startup_cost!(fnm)
    obj_ancillary_costs!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    return fnm
end
