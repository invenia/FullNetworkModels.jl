"""
    unit_commitment(system::System) -> Model

Defines the unit commitment default template. Receives a `system` from FullNetworkDataPrep
and returns a JuMP model.

TODO: This template will be updated as the implementation of the package progresses.
"""
function unit_commitment(system::System, solver)
    # Initialize FNM
    fnm = FullNetworkModel(system, solver)
    # Add variables
    add_thermal_generation!(fnm)
    add_commitment!(fnm)
    return fnm
end
