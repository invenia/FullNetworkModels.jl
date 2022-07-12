"""
    (ed::EconomicDispatch)(
        system::System, solver=nothing, datetimes=get_datetimes(system)
    ) -> FullNetworkModel{ED}

Defines the economic dispatch formulation.

Receives a `System` and returns a `FullNetworkModel` with the formulation:

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

And if thermal branch flow limits are included, via `branch_flows=true`:

$(latex(con_thermal_branch!))

!!! note "Ramp Rates"
    While a real-time economic dispatch formulation would usually include ramp rate
    constraints for intervals of 5 and 10 min, these are _not_ being considerded here,
    since the economic dispatch model built here is solved hourly, and its highly
    likely that these constraints are not binding within an hourly time period.

Arguments:
 - `system::SystemRT`: The FullNetworkSystems system that provides the input data.
 - `solver`: The solver of choice, e.g. `HiGHS.Optimizer`.
 - `datetimes=get_datetimes(system)`: The time periods considered in the model.
"""
function (ed::EconomicDispatch)(
    ::Type{MISO}, system::SystemRT, solver=nothing, datetimes=get_datetimes(system)
)
    sl = ed.slack
    branch_flows = ed.branch_flows
    threshold = ed.threshold
    # Get the individual slack values to be used in each soft constraint
    # Initialize FNM
    @timeit_debug get_timer("FNTimer") "initialise FNM" fnm = FullNetworkModel{ED}(system, datetimes)
    # Variables
    @timeit_debug get_timer("FNTimer") "add variables to model" begin
        var_thermal_generation!(fnm)
        var_ancillary_services!(fnm)
    end
    # Constraints
    @timeit_debug get_timer("FNTimer") "add constraints to model" begin
        con_generation_limits!(fnm)
        con_ancillary_limits!(fnm)
        con_regulation_requirements!(fnm; slack=sl.ancillary_requirements)
        con_operating_reserve_requirements!(fnm; slack=sl.ancillary_requirements)
        con_energy_balance!(fnm; slack=sl.energy_balance)
        branch_flows && @timeit_debug get_timer("FNTimer") "thermal branch constraints" begin
            con_thermal_branch!(fnm; threshold)
        end
    end
    # Objectives
    @timeit_debug get_timer("FNTimer") "add objectives to model" begin
        obj_thermal_variable_cost!(fnm)
        obj_ancillary_costs!(fnm)
    end
    @timeit_debug get_timer("FNTimer") "set optimizer" set_optimizer(fnm, solver; add_bridges=false)
    return fnm
end

"""
    function economic_dispatch(args...; kwargs...) -> FullNetworkModel{ED}

Returns a [`FullNetworkModel`](@ref) with the `EconomicDispatch` formulation according to the
selected `kwargs`. Using `economic_dispatch` is equivalent to defining a `EconomicDispatch`
struct and then using it to create a FullNetworkModel in one step, i.e.,

```julia
fnm = economic_dispatch(MISO, system, solver; branch_flows=true)
```

is equivalent to

```julia
ed = EconomicDispatch(branch_flows=true)
fnm = ed(MISO, system, solver)
```
"""
economic_dispatch(args...; kwargs...) = EconomicDispatch(; kwargs...)(args...)
