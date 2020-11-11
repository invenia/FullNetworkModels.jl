function tests_thermal_generation(fnm)
    @testset "Variables named `p` were created with the correct indices" begin
        @test has_variable(fnm.model, "p")
        @test issetequal(
            fnm.model[:p].axes[1],
            get_unit_codes(ThermalGen, fnm.system)
        )
        @test issetequal(fnm.model[:p].axes[2], 1:24)
    end
    return nothing
end

function tests_commitment(fnm)
    @testset "Variables named `u` were created with the correct indices" begin
        @test has_variable(fnm.model, "u")
        @test issetequal(
            fnm.model[:u].axes[1],
            get_unit_codes(ThermalGen, fnm.system)
        )
        @test issetequal(fnm.model[:u].axes[2], 1:24)
    end
    @testset "Created variables are binary" begin
        @test all(is_binary, fnm.model[:u].data)
    end
    return nothing
end

@testset "Variables" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "add_thermal_generation!" begin
        add_thermal_generation!(fnm)
        tests_thermal_generation(fnm)
        @test !has_variable(fnm.model, "u")
    end
    @testset "add_commitment!" begin
        add_commitment!(fnm)
        tests_commitment(fnm)
    end
end
