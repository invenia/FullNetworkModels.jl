@testset "Templates" begin
    @testset "unit_commitment" begin
        fnm = unit_commitment(TEST_SYSTEM, GLPK.Optimizer)
        tests_thermal_generation(fnm)
        tests_commitment(fnm)
        tests_generation_limits(fnm)
    end
end
