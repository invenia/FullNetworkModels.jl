"""
    (uc::UnitCommitment)(
        ::Type{MISO}, system::SystemDA, solver=nothing, datetimes=get_datetimes(system)
    ) -> FullNetworkModel{UC}

Defines the unit commitment formulation.

Receives a `SystemDA` and returns a [`FullNetworkModel`](@ref) with the formulation:

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

And if ramp rates are included, via `ramp_rates=true`:

$(latex(con_generation_ramp_rates!))
$(latex(con_ancillary_ramp_rates!))

And if thermal branch flow limits are included, via `branch_flows=true`:

$(latex(con_thermal_branch!))

# Arguments
 - `system::SystemDA`: The FullNetworkSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `HiGHS.Optimizer`.
 - `datetimes=get_datetimes(system)`: The time periods considered in the model.
"""
function (uc::UnitCommitment)(
    ::Type{MISO}, system::SystemDA, solver=nothing, datetimes=get_datetimes(system)
)
    sl = uc.slack
    branch_flows = uc.branch_flows
    ramp_rates = uc.ramp_rates
    relax_integrality = uc.relax_integrality
    threshold = uc.threshold
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
        con_regulation_requirements!(fnm; slack=sl.ancillary_requirements)
        con_operating_reserve_requirements!(fnm; slack=sl.ancillary_requirements)
        con_energy_balance!(fnm; slack=sl.energy_balance)
        con_must_run!(fnm)
        con_availability!(fnm)
        if ramp_rates
            con_generation_ramp_rates!(fnm; slack=sl.ramp_rates)
            con_ancillary_ramp_rates!(fnm)
        end
        branch_flows && @timeit_debug get_timer("FNTimer") "thermal branch constraints" begin
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
    @timeit_debug get_timer("FNTimer") "set optimizer" set_optimizer(fnm, solver; add_bridges=false)
    return fnm
end

"""
    function unit_commitment(args...; kwargs...) -> FullNetworkModel{UC}

Returns a [`FullNetworkModel`](@ref) with the `UnitCommitment` formulation according to the
selected `kwargs`. Using `unit_commitment` is equivalent to defining a `UnitCommitment`
struct and then using it to create a FullNetworkModel in one step, i.e.,

```julia
fnm = unit_commitment(MISO, system, solver; branch_flows=true)
```

is equivalent to

```julia
uc = UnitCommitment(branch_flows=true)
fnm = uc(MISO, system, solver)
```
"""
unit_commitment(args...; kwargs...) = UnitCommitment(; kwargs...)(args...)
