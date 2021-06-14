@testset "Basic feasibility checks" begin
    @test basic_feasibility_checks(TEST_SYSTEM) # should have no issues
    # Now let's create versions of the test system that have some glaring data issues
    # resulting in infeasibilities
    high_demand_system = deepcopy(TEST_SYSTEM)
end
