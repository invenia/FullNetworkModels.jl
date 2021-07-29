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

function tests_startup_shutdown(fnm, n_periods)
    tests_thermal_variable(fnm, "v", n_periods)
    tests_thermal_variable(fnm, "w", n_periods)
    @test sprint(show, constraint_by_name(
        fnm.model, "startup_shutdown_definition[7,2]"
    )) == "startup_shutdown_definition[7,2] : -u[7,1] + u[7,2] - v[7,2] + w[7,2] = 0.0"
    @test !has_constraint(fnm.model, "startup_shutdown_definition[7,1]")
    @test sprint(show, constraint_by_name(
        fnm.model, "startup_shutdown_definition_initial[7]"
    )) == "startup_shutdown_definition_initial[7] : u[7,1] - v[7,1] + w[7,1] = 1.0"
    return nothing
end

function tests_bid_variables(fnm, label, bidtype, n_periods)
    @testset "Variables named `$label` were created with the correct indices" begin
        @test has_variable(fnm.model, label)
        @test issetequal(
            fnm.model[Symbol(label)].axes[1], get_bid_names(bidtype, fnm.system)
        )
        @test issetequal(fnm.model[Symbol(label)].axes[2], 1:n_periods)
    end
    return nothing
end

@testset "Variables" begin
    fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
    n_periods = get_forecast_horizon(fnm.system)
    @testset "var_thermal_generation!" begin
        var_thermal_generation!(fnm)
        tests_thermal_variable(fnm, "p", n_periods)
        @test !has_variable(fnm.model, "u")
    end
    @testset "var_commitment!" begin
        var_commitment!(fnm)
        tests_commitment(fnm, n_periods)
    end
    @testset "var_startup_shutdown!" begin
        var_startup_shutdown!(fnm)
        tests_startup_shutdown(fnm, n_periods)
    end
    @testset "var_ancillary_services!" begin
        var_ancillary_services!(fnm)
        @testset for service in ("r_reg", "u_reg", "r_spin", "r_on_sup", "r_off_sup")
            tests_thermal_variable(fnm, service, n_periods)
        end
    end
    @testset "var_bids!" begin
        var_bids!(fnm)
        tests_bid_variables(fnm, "inc", Increment, n_periods)
        tests_bid_variables(fnm, "dec", Decrement, n_periods)
        tests_bid_variables(fnm, "psd", PriceSensitiveDemand, n_periods)
    end
end
