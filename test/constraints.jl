function tests_generation_limits(fnm)
    @testset "Test if constraints were created with the correct indices" begin
        @test has_constraint(fnm.model, "generation_min")
        @test has_constraint(fnm.model, "generation_max")
        @test issetequal(fnm.model[:generation_min].axes[1], (7, 3))
        @test issetequal(fnm.model[:generation_min].axes[2], 1:24)
        @test issetequal(fnm.model[:generation_max].axes[1], (7, 3))
        @test issetequal(fnm.model[:generation_max].axes[2], 1:24)
    end
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
    @testset "ancillary_service_limits!" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_thermal_generation!(fnm)
        add_commitment!(fnm)
        add_ancillary_services!(fnm)
        ancillary_service_limits!(fnm)
        @test sprint(show, constraint_by_name(fnm.model, "ancillary_max[7,1]")) ==
            "ancillary_max[7,1] : p[7,1] - 5 u[7,1] + r_reg[7,1] + 0.5 u_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
        @test sprint(show, constraint_by_name(fnm.model, "ancillary_min[7,1]")) ==
            "ancillary_min[7,1] : p[7,1] - 0.5 u[7,1] - r_reg[7,1] - 0.5 u_reg[7,1] ≥ 0.0"
        @test sprint(show, constraint_by_name(fnm.model, "regulation_max[7,1]")) ==
            "regulation_max[7,1] : r_reg[7,1] ≤ 1.75"
        @test sprint(show, constraint_by_name(fnm.model, "spin_and_sup_max[7,1]")) ==
            "spin_and_sup_max[7,1] : -4.5 u[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
        @test sprint(show, constraint_by_name(fnm.model, "off_sup_max[7,1]")) ==
            "off_sup_max[7,1] : 4.5 u[7,1] + r_off_sup[7,1] ≤ 4.5"
    end
end
