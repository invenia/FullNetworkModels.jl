"""
    unit_commitment(
        system::System, solver=nothing, datetimes=get_forecast_timestamps(system);
        relax_integrality=false, slack=nothing, threshold=$_SF_THRESHOLD,
        branch_flow_limits::Bool=false, ramp_rates::Bool=true,
    ) -> FullNetworkModel{UC}

Defines the unit commitment formulation.

Receives a `System` and returns a [`FullNetworkModel`](@ref) with the formulation:

$(_write_formulation(
    objectives=[
        latex(_obj_thermal_variable_cost!),
        latex(obj_thermal_noload_cost!),
        latex(obj_thermal_startup_cost!),
        latex(obj_ancillary_costs!),
        latex(_obj_bid_variable_cost!),
    ],
    constraints=[
        latex(_var_thermal_gen_blocks_uc!),
        latex(_con_generation_limits_uc!),
        latex(_con_startup_shutdown!),
        latex(con_ancillary_limits_uc!),
        latex(con_regulation_requirements!),
        latex(con_operating_reserve_requirements!),
        latex(_con_reg_commitment!),
        latex(con_energy_balance_uc!),
        latex(con_must_run!),
        latex(con_availability!),
        latex(_var_bid_blocks!),
    ],
    variables=[
        latex(var_thermal_generation!),
        latex(var_commitment!),
        latex(_var_startup_shutdown!),
        latex(_var_ancillary_services!),
        latex(_var_reg_commitment!),
        latex(var_bids!),
    ]
))

And if ramp rates are include, via `ramp_rates=true`:

$(latex(con_generation_ramp_rates!))
$(latex(con_ancillary_ramp_rates!))

And if thermal branch flow limits are include, via `branch_flow_limits=true`:

$(latex(con_thermal_branch!))

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `HiGHS.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=nothing`: The slack penalty for the soft constraints.
   For more info on specifying slacks, refer to the [docs on soft constraints](@ref soft_constraints).
 - `threshold=$_SF_THRESHOLD`: The threshold (cutoff value) to be applied to the shift factors. Only relevant when `branch_flow_limits=true`.
 - `branch_flow_limits::Bool=false`: Whether or not to inlcude thermal branch flow constraints.
 - `ramp_rates::Bool=true`: Whether or not to include ramp rate constraints.
"""
function unit_commitment(
    system::System, solver=nothing, datetimes=get_forecast_timestamps(system);
    relax_integrality=false, slack=nothing, threshold=_SF_THRESHOLD,
    branch_flow_limits::Bool=false, ramp_rates::Bool=true
)
    # Get the individual slack values to be used in each soft constraint
    @timeit_debug get_timer("FNTimer") "specify slacks" sl = _expand_slacks(slack)
    # Initialize FNM
    @timeit_debug get_timer("FNTimer") "initialise FNM" fnm = FullNetworkModel{UC}(system, datetimes)
    # Variables
    @timeit_debug get_timer("FNTimer") "add variables to model" begin
        var_thermal_generation!(fnm)
        var_commitment!(fnm)
        var_startup_shutdown!(fnm)
        var_ancillary_services!(fnm)
        var_bids!(fnm)
    end
    # Constraints
    @timeit_debug get_timer("FNTimer") "add constraints to model" begin
        con_generation_limits!(fnm)
        con_ancillary_limits!(fnm)
        con_regulation_requirements!(fnm; slack=sl[:ancillary_requirements])
        con_operating_reserve_requirements!(fnm; slack=sl[:ancillary_requirements])
        con_energy_balance!(fnm; slack=sl[:energy_balance])
        con_must_run!(fnm)
        con_availability!(fnm)
        if ramp_rates
            con_generation_ramp_rates!(fnm; slack=sl[:ramp_rates])
            con_ancillary_ramp_rates!(fnm)
        end
        branch_flow_limits && @timeit_debug get_timer("FNTimer") "thermal branch constraints" begin
            con_thermal_branch!(fnm; threshold)
        end
    end
    # Objectives
    @timeit_debug get_timer("FNTimer") "add objectives to model" begin
        obj_thermal_variable_cost!(fnm)
        obj_thermal_noload_cost!(fnm)
        obj_thermal_startup_cost!(fnm)
        obj_ancillary_costs!(fnm)
        obj_bids!(fnm)
    end
    if relax_integrality
        @timeit_debug get_timer("FNTimer") "relax integrality" JuMP.relax_integrality(fnm.model)
    end
    @timeit_debug get_timer("FNTimer") "set optimizer" set_optimizer(fnm, solver)
    return fnm
end

@deprecate(
    unit_commitment_no_ramps(
        system::System, solver=nothing, datetimes=get_forecast_timestamps(system);
        relax_integrality=false, slack=nothing,
    ),
    unit_commitment(
        system, solver, datetimes;
        relax_integrality=relax_integrality, slack=slack,
        ramp_rates=false
    )
)
@deprecate(
    unit_commitment_branch_flow_limits(
        system::System, solver=nothing, datetimes=get_forecast_timestamps(system);
        relax_integrality=false, slack=nothing, threshold=_SF_THRESHOLD
    ),
    unit_commitment(
        system, solver, datetimes;
        relax_integrality=relax_integrality, slack=slack, threshold=threshold,
        branch_flow_limits=true
    )
)
@deprecate(
    unit_commitment_no_ramps_branch_flow_limits(
        system::System, solver=nothing, datetimes=get_forecast_timestamps(system);
        relax_integrality=false, slack=nothing, threshold=_SF_THRESHOLD
    ),
    unit_commitment(
        system, solver, datetimes;
        relax_integrality=relax_integrality, slack=slack, threshold=threshold,
        branch_flow_limits=true, ramp_rates=false
    )
)
