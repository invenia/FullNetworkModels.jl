"""
    unit_commitment(system::System, solver; relax_integrality=false) -> FullNetworkModel

Defines the unit commitment default template; the keyword `relax_integrality` can be set to
`true` to relax all binary variables. Receives a `system` from FullNetworkDataPrep and
returns a `FullNetworkModel` with a `model` with the following formulation:

$(_write_formulation(
    objectives=[
        _latex(_thermal_variable_cost_objective!),
        _latex(thermal_noload_cost!),
        _latex(thermal_startup_cost!),
        _latex(ancillary_service_costs!),
    ],
    constraints=[
        _latex(_add_thermal_gen_blocks!; commitment=true),
        _latex(generation_limits!; commitment=true),
        _latex(_add_startup_shutdown_constraints!),
        _latex(ancillary_service_limits!),
        _latex(regulation_requirements!),
        _latex(operating_reserve_requirements!),
        _latex(_add_ancillary_services_constraints!),
        _latex(ramp_rates!),
        _latex(energy_balance!),
    ],
    variables=[
        _latex(add_thermal_generation!),
        _latex(add_commitment!),
        _latex(_add_startup_shutdown_variables!),
        _latex(_add_ancillary_services_variables!),
    ]
))
"""
function unit_commitment(system::System, solver; relax_integrality=false)
    # Initialize FNM
    fnm = FullNetworkModel(system, solver)
    # Variables
    add_thermal_generation!(fnm)
    add_commitment!(fnm)
    add_startup_shutdown!(fnm)
    add_ancillary_services!(fnm)
    # Constraints
    generation_limits!(fnm)
    ancillary_service_limits!(fnm)
    regulation_requirements!(fnm)
    operating_reserve_requirements!(fnm)
    ramp_rates!(fnm)
    energy_balance!(fnm)
    # Objectives
    thermal_variable_cost!(fnm)
    thermal_noload_cost!(fnm)
    thermal_startup_cost!(fnm)
    ancillary_service_costs!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    return fnm
end
