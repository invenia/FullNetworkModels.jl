function tests_thermal_variable(fnm, label, n_periods)
    @testset "Variables named `$label` were created with the correct indices" begin
        @test has_variable(fnm.model, label)
        @test issetequal(
            fnm.model[Symbol(label)].axes[1],
            get_unit_codes(ThermalGen, fnm.system)
        )
        @test issetequal(fnm.model[Symbol(label)].axes[2], 1:n_periods)
    end
    return nothing
end

function tests_commitment(fnm, n_periods)
    tests_thermal_variable(fnm, "u", n_periods)
    @testset "Created variables are binary" begin
        @test all(is_binary, fnm.model[:u].data)
    end
    return nothing
end

@testset "Variables" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    n_periods = get_forecasts_horizon(fnm.system)
    @testset "add_thermal_generation!" begin
        add_thermal_generation!(fnm)
        tests_thermal_variable(fnm, "p", n_periods)
        @test !has_variable(fnm.model, "u")
    end
    @testset "add_commitment!" begin
        add_commitment!(fnm)
        tests_commitment(fnm, n_periods)
    end
    @testset "add_ancillary_services!" begin
        add_ancillary_services!(fnm)
        @testset for service in ("r_reg", "u_reg", "r_spin", "r_on_sup", "r_off_sup")
            tests_thermal_variable(fnm, service, n_periods)
        end
    end
end
