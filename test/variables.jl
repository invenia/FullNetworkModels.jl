@testset "Variables" begin
    system = fake_3bus_system(MISO)
    fnm = FullNetworkModel(system, GLPK.Optimizer)
    @testset "add_thermal_generation!" begin
        add_thermal_generation!(fnm)
        # Check if variables named `p` were created with the correct indices
        @test issetequal(
            fnm.model[:p].axes[1],
            InHouseFNM._get_unit_codes(ThermalGen, fnm.system)
        )
        @test issetequal(fnm.model[:p].axes[2], 1:24)
    end
    @testset "add_commitment!" begin
        add_commitment!(fnm)
        # Check if variables named `u` were created with the correct indices
        @test issetequal(
            fnm.model[:u].axes[1],
            InHouseFNM._get_unit_codes(ThermalGen, fnm.system)
        )
        @test issetequal(fnm.model[:u].axes[2], 1:24)
        # Check if the created variables are binary
        @test all(is_binary, fnm.model[:u].data)
    end
end
