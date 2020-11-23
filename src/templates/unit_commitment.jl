"""
    unit_commitment(system::System) -> FullNetworkModel

Defines the unit commitment default template. Receives a `system` from FullNetworkDataPrep
and returns a `FullNetworkModel` with a `model` with the following formulation:

$(_write_formulation(
    objectives=[
        _thermal_variable_cost_objective_latex(),
        _thermal_noload_cost_latex(),
        _ancillary_service_costs_latex(),
    ],
    constraints=[
        _thermal_variable_cost_constraints_latex(commitment=true),
        _generation_limits_latex(commitment=true),
        _ancillary_service_limits_latex(),
        _regulation_requirements_latex(),
        _operating_reserve_requirements_latex(),
    ],
    variables=[
        _add_thermal_generation_latex(),
        _add_commitment_latex(),
        _add_ancillary_services_latex(),
    ]
))
"""
function unit_commitment(system::System, solver)
    # Initialize FNM
    fnm = FullNetworkModel(system, solver)
    # Variables
    add_thermal_generation!(fnm)
    add_commitment!(fnm)
    add_ancillary_services!(fnm)
    # Constraints
    generation_limits!(fnm)
    ancillary_service_limits!(fnm)
    regulation_requirements!(fnm)
    operating_reserve_requirements!(fnm)
    # Objectives
    thermal_variable_cost!(fnm)
    ancillary_service_costs!(fnm)
    thermal_noload_cost!(fnm)
    return fnm
end
