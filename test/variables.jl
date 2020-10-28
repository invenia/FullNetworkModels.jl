function tests_thermal_generation(fnm)
    # Check if variables named `p` were created with the correct indices
    @test issetequal(
        fnm.model[:p].axes[1],
        InHouseFNM._get_unit_codes(ThermalGen, fnm.system)
    )
    @test issetequal(fnm.model[:p].axes[2], 1:24)
    return nothing
end

function tests_commitment(fnm)
    # Check if variables named `u` were created with the correct indices
    @test issetequal(
        fnm.model[:u].axes[1],
        InHouseFNM._get_unit_codes(ThermalGen, fnm.system)
    )
    @test issetequal(fnm.model[:u].axes[2], 1:24)
    # Check if the created variables are binary
    @test all(is_binary, fnm.model[:u].data)
    return nothing
end

@testset "Variables" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "add_thermal_generation!" begin
        add_thermal_generation!(fnm)
        tests_thermal_generation(fnm)
        @test !InHouseFNM._has_commitment(fnm)
    end
    @testset "add_commitment!" begin
        add_commitment!(fnm)
        tests_commitment(fnm)
        @test InHouseFNM._has_commitment(fnm)
    end
end
