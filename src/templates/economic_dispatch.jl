"""
    economic_dispatch(
        system::System, solver; relax_integrality=false
    ) -> FullNetworkModel

Defines the economic dispatch default template.
Receives a `system` from FullNetworkDataPrep and returns a `FullNetworkModel` with a
`model` with the following formulation:

$(_write_formulation(
    objectives=[
        _latex(_obj_thermal_variable_cost!),
        _latex(obj_ancillary_costs!),
    ],
    constraints=[
        _latex(_var_thermal_gen_blocks!; commitment=true), # [Pending] Change u for U
        _latex(_con_generation_limits_dispatch!), # [Done]
        _latex(con_ancillary_limits_dispatch!), # [Next] Change u for U and remove the 0.5
        _latex(con_regulation_requirements!), # [Pending] The same, but in RT they are Soft Constraints
        _latex(con_operating_reserve_requirements!), # [Pending] The same, but in RT they are Soft Constraints
        #_latex(con_ramp_rates!), # [Skipped] Only generation_ramp_rates is needed, but has to be modified to include Contingency Reserve and alpha, but not binding in 1hr, skipped for now
        _latex(con_energy_balance!), # [Pending] No virtuals, no price sentive demands, all demands are fixed
    ],
    variables=[
        _latex(var_thermal_generation!),
        _latex(_var_ancillary_services!),
    ]
))

Arguments:
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `GLPK.Optimizer`.

Keyword arguments:
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function economic_dispatch(system::System, solver)
    # Initialize FNM
    fnm = FullNetworkModel(system, solver)
    # Variables
    var_thermal_generation!(fnm)
    var_ancillary_services!(fnm)

    # Constraints
    con_generation_limits!(fnm)
    con_ancillary_limits!(fnm)
    con_regulation_requirements!(fnm)
    con_operating_reserve_requirements!(fnm)
    #con_ramp_rates!(fnm)
    con_energy_balance!(fnm)

    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_ancillary_costs!(fnm)
    return fnm
end
