"""
    unit_commitment(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment default template.
Receives a `System` from FullNetworkDataPrep.jl and returns a [`FullNetworkModel`](@ref)
with a `Model` with the following formulation:

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
        latex(con_generation_ramp_rates!),
        latex(con_ancillary_ramp_rates!),
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

Thermal branch flow limits are not considered in this formulation.

See also [`unit_commitment_soft_ramps`](@ref) and [`unit_commitment_no_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=nothing`: The slack penalty for the soft constraints (i.e. slack=1e4).
"""
function unit_commitment(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    relax_integrality=false, slack=1e4
)
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
        con_regulation_requirements!(fnm)
        con_operating_reserve_requirements!(fnm)
        con_generation_ramp_rates!(fnm)
        con_ancillary_ramp_rates!(fnm)
        con_energy_balance!(fnm)
        con_must_run!(fnm)
        con_availability!(fnm)
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

"""
    unit_commitment_soft_ramps(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        slack=1e4, relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment template with soft generation ramp constraints.
Receives a `system` from FullNetworkDataPrep and returns a [`FullNetworkModel`](@ref) with a
`model` with the same formulation as [`unit_commitment`], except for the ramp constraints,
which are modeled as soft constraints with slack variables.

Thermal branch flow limits are not considered in this formulation.

See also [`unit_commitment`](@ref) and [`unit_commitment_no_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `slack=1e4`: The slack penalty for the soft constraints.
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function unit_commitment_soft_ramps(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    slack=1e4, relax_integrality=false
)
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
        con_regulation_requirements!(fnm)
        con_operating_reserve_requirements!(fnm)
        con_generation_ramp_rates!(fnm; slack=slack)
        con_ancillary_ramp_rates!(fnm)
        con_energy_balance!(fnm)
        con_must_run!(fnm)
        con_availability!(fnm)
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
"""
    unit_commitment_soft_ramps(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        slack=1e4, relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment template with soft generation ramp constraints.
Receives a `system` from FullNetworkDataPrep and returns a [`FullNetworkModel`](@ref) with a
`model` with the same formulation as [`unit_commitment`], except for the ramp constraints,
which are modeled as soft constraints with slack variables.

Thermal branch flow limits are not considered in this formulation.

See also [`unit_commitment`](@ref) and [`unit_commitment_no_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `slack=1e4`: The slack penalty for the soft constraints.
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
"""
function unit_commitment_soft_ramps(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    slack=1e4, relax_integrality=false
    )
    # Initialize FNM
    fnm = FullNetworkModel{UC}(system, datetimes)
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
    con_generation_ramp_rates!(fnm; slack)
    con_ancillary_ramp_rates!(fnm)
    con_energy_balance!(fnm)
    con_must_run!(fnm)
    con_availability!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_thermal_startup_cost!(fnm)
    obj_ancillary_costs!(fnm)
    obj_bids!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    set_optimizer(fnm, solver)
    return fnm
end

"""
    unit_commitment_no_ramps(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment template with no ramp constraints.
Receives a `system` from FullNetworkDataPrep and returns a [`FullNetworkModel`](@ref) with a
`model` with the same formulation as [`unit_commitment`](@ref), except for ramp constraints,
which are omitted.

Thermal branch flow limits are not considered in this formulation.

See also [`unit_commitment`](@ref) and [`unit_commitment_branch_flow_limits`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=nothing`: The slack penalty for the soft constraints (i.e. slack=1e4).
"""
function unit_commitment_no_ramps(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    relax_integrality=false, slack=nothing
)
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
        con_regulation_requirements!(fnm)
        con_operating_reserve_requirements!(fnm)
        con_energy_balance!(fnm)
        con_must_run!(fnm)
        con_availability!(fnm)
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

"""
    unit_commitment_branch_flow_limits(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment default template.
Receives a `System` from FullNetworkDataPrep.jl and returns a [`FullNetworkModel`](@ref)
with a `Model` with the following formulation:

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
        latex(con_generation_ramp_rates!),
        latex(con_ancillary_ramp_rates!),
        latex(con_energy_balance_uc!),
        latex(con_must_run!),
        latex(con_availability!),
        latex(_con_nodal_net_injection_uc!),
        latex(_con_branch_flows!),
        latex(_con_branch_flow_limits!),
        latex(_con_branch_flow_slacks!),
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

Thermal branch flow limits are considered in this formulation.

See also [`unit_commitment`](@ref) and [`unit_commitment_no_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=nothing`: The slack penalty for the soft constraints (i.e. slack=1e4).
"""
function unit_commitment_branch_flow_limits(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    relax_integrality=false, slack=1e4
)
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
        con_regulation_requirements!(fnm)
        con_operating_reserve_requirements!(fnm)
        con_generation_ramp_rates!(fnm)
        con_ancillary_ramp_rates!(fnm)
        con_energy_balance!(fnm)
        con_must_run!(fnm)
        con_availability!(fnm)
        @timeit_debug get_timer("FNTimer") "thermal branch constraints" con_thermal_branch!(fnm)
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

"""
    unit_commitment_soft_ramps_branch_flow_limits(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        slack=1e4, relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment template with soft generation ramp constraints and branch flow
limits. Receives a `system` from FullNetworkDataPrep and returns a [`FullNetworkModel`](@ref)
with a `model` with the same formulation as [`unit_commitment_branch_flow_limits`], except
for the ramp constraints, which are modeled as soft constraints with slack variables.

See also [`unit_commitment_branch_flow_limits`](@ref) and [`unit_commitment_soft_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `slack=1e4`: The slack penalty for the soft constraints.
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=1e4`: The slack penalty for the soft constraints.
"""
function unit_commitment_soft_ramps_branch_flow_limits(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    slack=1e4, relax_integrality=false
)
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
        con_regulation_requirements!(fnm)
        con_operating_reserve_requirements!(fnm)
        con_generation_ramp_rates!(fnm; slack=slack)
        con_ancillary_ramp_rates!(fnm)
        con_energy_balance!(fnm)
        con_must_run!(fnm)
        con_availability!(fnm)
        @timeit_debug get_timer("FNTimer") "thermal branch constraints" con_thermal_branch!(fnm)
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
"""
    unit_commitment_soft_ramps_branch_flow_limits(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        slack=1e4, relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment template with soft generation ramp constraints and branch flow
limits. Receives a `system` from FullNetworkDataPrep and returns a [`FullNetworkModel`](@ref)
with a `model` with the same formulation as [`unit_commitment_branch_flow_limits`], except
for the ramp constraints, which are modeled as soft constraints with slack variables.

See also [`unit_commitment_branch_flow_limits`](@ref) and [`unit_commitment_soft_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `slack=1e4`: The slack penalty for the soft constraints.
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=1e4`: The slack penalty for the soft constraints.
"""
function unit_commitment_soft_ramps_branch_flow_limits(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    slack=1e4, relax_integrality=false
    )
    # Initialize FNM
    fnm = FullNetworkModel{UC}(system, datetimes)
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
    con_generation_ramp_rates!(fnm; slack)
    con_ancillary_ramp_rates!(fnm)
    con_energy_balance!(fnm)
    con_must_run!(fnm)
    con_availability!(fnm)
    con_thermal_branch!(fnm)
    # Objectives
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_thermal_startup_cost!(fnm)
    obj_ancillary_costs!(fnm)
    obj_bids!(fnm)
    if relax_integrality
        JuMP.relax_integrality(fnm.model)
    end
    set_optimizer(fnm, solver)
    return fnm
end
"""
    unit_commitment_no_ramps_branch_flow_limits(
        system::System, solver, datetimes=get_forecast_timestamps(system);
        relax_integrality=false
    ) -> FullNetworkModel{UC}

Defines the unit commitment template with branch flow limits but no ramp constraints.
Receives a `system` from FullNetworkDataPrep and returns a [`FullNetworkModel`](@ref) with a
`model` with the same formulation as [`unit_commitment_branch_flow_limits`](@ref), except for
ramp constraints, which are omitted.

See also [`unit_commitment_branch_flow_limits`](@ref) and [`unit_commitment_no_ramps`](@ref).

# Arguments
 - `system::System`: The PowerSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `Cbc.Optimizer`.
 - `datetimes=get_forecast_timestamps(system)`: The time periods considered in the model.

# Keywords
 - `relax_integrality=false`: If set to `true`, binary variables will be relaxed.
 - `slack=1e4`: The slack penalty for the soft constraints.
"""
function unit_commitment_no_ramps_branch_flow_limits(
    system::System, solver, datetimes=get_forecast_timestamps(system);
    relax_integrality=false, slack=1e4
)
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
        con_regulation_requirements!(fnm)
        con_operating_reserve_requirements!(fnm)
        con_energy_balance!(fnm)
        con_must_run!(fnm)
        con_availability!(fnm)
        @timeit_debug get_timer("FNTimer") "thermal branch constraints" con_thermal_branch!(fnm)
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
