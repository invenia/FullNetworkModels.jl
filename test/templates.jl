@testset "Templates" begin
    @testset "unit_commitment" begin
        fnm = unit_commitment(TEST_SYSTEM, GLPK.Optimizer)
        n_periods = get_forecasts_horizon(fnm.system)
        tests_thermal_variable(fnm, "p", n_periods)
        tests_commitment(fnm, n_periods)
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_ancillary_costs(fnm)
        tests_thermal_noload_cost(fnm)
        tests_ancillary_limits(fnm)
        tests_regulation_requirements(fnm)
        tests_operating_reserve_requirements(fnm)
    end
end
