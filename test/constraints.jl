function tests_generation_limits(fnm)
    # Check if variables named `p` were created with the correct indices
    @test has_constraint(fnm.model, "generation_min")
    @test has_constraint(fnm.model, "generation_max")
    @test issetequal(fnm.model[:generation_min].axes[1], (7, 3))
    @test issetequal(fnm.model[:generation_min].axes[2], 1:24)
    @test issetequal(fnm.model[:generation_max].axes[1], (7, 3))
    @test issetequal(fnm.model[:generation_max].axes[2], 1:24)
    return nothing
end

@testset "Constraints" begin
    @testset "generation_limits!" begin
        # Test if trying to add constraints without having variables throws error
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        @test_throws AssertionError generation_limits!(fnm)
        # Test for economic dispatch (just thermal generation added)
        add_thermal_generation!(fnm)
        generation_limits!(fnm)
        tests_generation_limits(fnm)
        # Test for unit commitment (both thermal generation and commitment added)
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_thermal_generation!(fnm)
        add_commitment!(fnm)
        generation_limits!(fnm)
        tests_generation_limits(fnm)
    end
end
