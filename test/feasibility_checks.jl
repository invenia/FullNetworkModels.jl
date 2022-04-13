@testset "Basic feasibility checks" begin
    @test basic_feasibility_checks(TEST_SYSTEM) # should have no issues
    # Now let's create versions of the test system that have some glaring data issues
    # resulting in infeasibilities

    # System with too much demand
    high_demand_system = deepcopy(TEST_SYSTEM)
    n_periods = get_forecast_horizon(high_demand_system)
    load1 = first(get_components(PowerLoad, high_demand_system))
    remove_time_series!(high_demand_system, Forecast)
    datetimes = get_time_series_timestamps(SingleTimeSeries, load1, "active_power")
    remove_time_series!(high_demand_system, SingleTimeSeries, load1, "active_power")
    ta = TimeArray(datetimes, fill(1e4, n_periods))
    add_time_series!(high_demand_system, load1, SingleTimeSeries("active_power", ta))
    transform_single_time_series!(high_demand_system, n_periods, Hour(0))
    @test get_fixed_loads(high_demand_system)[load1.name, :] ==
        DenseAxisArray(fill(1e4, n_periods), datetimes)
    @test !basic_feasibility_checks(high_demand_system)

    # System with infeasible ramp
    system_infeasible_ramp = deepcopy(TEST_SYSTEM)
    gens = collect(get_components(ThermalGen, system_infeasible_ramp))
    gens[1].active_power = 50.0
    @test get_initial_generation(system_infeasible_ramp)[7] == 50.0
    @test !basic_feasibility_checks(system_infeasible_ramp)

    # System with huge ancillary requirement
    system_infeasible_req = deepcopy(TEST_SYSTEM)
    serv = get_component(Service, system_infeasible_req, "regulation_1")
    serv.requirement = 1e4
    @test !basic_feasibility_checks(system_infeasible_req)
end
