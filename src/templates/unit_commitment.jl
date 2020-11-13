"""
    unit_commitment(system::System) -> Model

Defines the unit commitment default template. Receives a `system` from FullNetworkDataPrep
and returns a JuMP model with the following formulation:

$(_write_formulation(
    objectives=[
        _thermal_variable_cost_objective(),
    ],
    constraints=[
        _thermal_variable_cost_constraints(commitment=true),
        _generation_limits(commitment=true),
    ],
    variables=[
        _add_thermal_generation(),
        _add_commitment(),
    ]
))

"""
function unit_commitment(system::System, solver)
    # Initialize FNM
    fnm = FullNetworkModel(system, solver)
    # Add variables
    add_thermal_generation!(fnm)
    add_commitment!(fnm)
    # Add constraints
    generation_limits!(fnm)
    # Add objectives
    thermal_variable_cost!(fnm)
    return fnm
end
