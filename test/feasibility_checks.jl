@testset "Basic feasibility checks" begin
    @test basic_feasibility_checks(TEST_SYSTEM) # should have no issues
    # Now let's create versions of the test system that have some glaring data issues
    # resulting in infeasibilities

    # System with too much demand
    high_demand_system = deepcopy(TEST_SYSTEM)
    n_periods = length(get_datetimes(high_demand_system))
    load_ts = get_load(high_demand_system)
    load_ts[1, :] .= fill(1e4, n_periods)
    @test !basic_feasibility_checks(high_demand_system)

    # System with infeasible ramp
    system_infeasible_ramp = deepcopy(TEST_SYSTEM)
    init_gen = get_initial_generation(system_infeasible_ramp)
    init_gen[1] = 50.0
    @test !basic_feasibility_checks(system_infeasible_ramp)

    # System with huge ancillary requirement
    system_infeasible_req = deepcopy(TEST_SYSTEM)
    zones = get_zones(system_infeasible_req)
    delete!(zones, 1)
    zone1_new = Zone(1, 1e4, 0.3, 0.3)
    insert!(zones, 1, zone1_new)
    @test !basic_feasibility_checks(system_infeasible_req)
end
