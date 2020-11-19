@testset "Templates" begin
    @testset "unit_commitment" begin
        fnm = unit_commitment(TEST_SYSTEM, GLPK.Optimizer)
        tests_thermal_generation(fnm)
        tests_commitment(fnm)
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_thermal_noload_cost(fnm)
    end
end
