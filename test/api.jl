@testset "API functions" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    fnm_rt = FullNetworkModel(TEST_SYSTEM_RT, GLPK.Optimizer)

    @testset "Prints" begin
        @test sprint(show, fnm) == "FullNetworkModel\nModel formulation: 0 variables\nSystem: 32 components, 24 time periods\n"
    end

    @testset "Accessors" begin
        system = fnm.system
        system_rt = fnm_rt.system

        n_periods = get_forecast_horizon(system)
        @test issetequal(get_unit_codes(ThermalGen, system), (7, 3))
        @test issetequal(get_load_names(PowerLoad, system), ("Load1_2", "Load2_3"))
        @test get_pmin(system) == Dict(
            3 => fill(0.5, n_periods), 7 => fill(0.5, n_periods)
        )
        @test get_pmax(system) == Dict(
            3 => fill(8.0, n_periods), 7 => fill(8.0, n_periods)
        )
        @test get_regmin(system) == Dict(
            3 => fill(0.5, n_periods), 7 => fill(0.5, n_periods)
        )
        @test get_regmax(system) == Dict(
            3 => fill(7.5, n_periods), 7 => fill(7.5, n_periods)
        )
        @test get_regulation_cost(system) == Dict(
            3 => fill(20_000, n_periods), 7 => fill(10_000, n_periods)
        )
        rng = MersenneTwister(1)
        stat_gen3 = bitrand(rng, n_periods)
        @test get_commitment_status(system_rt) == Dict(
            3 => stat_gen3, 7 => [false; fill(true, n_periods - 1)]
        )
        @test get_spinning_cost(system) == Dict(
            3 => fill(30_000, n_periods), 7 => fill(15_000, n_periods)
        )
        @test get_on_sup_cost(system) == Dict(
            3 => fill(35_000, n_periods), 7 => fill(17_500, n_periods)
        )
        @test get_off_sup_cost(system) == Dict(
            3 => fill(40_000, n_periods), 7 => fill(20_000, n_periods)
        )
        @test get_offer_curves(system) == Dict(
            3 => fill([(600.0, 0.5), (800.0, 1.0), (825.0, 5.0)], n_periods),
            7 => fill([(400.0, 0.5), (600.0, 1.0), (625.0, 5.0)], n_periods)
        )
        @test get_noload_cost(system) == Dict(
            3 => fill(200.0, n_periods), 7 => fill(100.0, n_periods)
        )
        @test get_startup_cost(system) == Dict(
            3 => fill(300.0, n_periods), 7 => fill(150.0, n_periods)
        )
        @test get_regulation_requirements(system) == Dict(
            1 => 0.3, 2 => 0.4, FullNetworkModels.MARKET_WIDE_ZONE => 0.8
        )
        @test get_operating_reserve_requirements(system) == Dict(
            1 => 0.4, 2 => 0.5, FullNetworkModels.MARKET_WIDE_ZONE => 1.2
        )
        @test issetequal(
            get_reserve_zones(system), (1, 2, FullNetworkModels.MARKET_WIDE_ZONE)
        )
        @test get_initial_generation(system) == Dict(3 => 1.0, 7 => 1.0)
        @test get_initial_commitment(system) == Dict(3 => 1.0, 7 => 1.0)
        @test get_minimum_uptime(system) == Dict(3 => 1.0, 7 => 1.0)
        @test get_minimum_downtime(system) == Dict(3 => 1.0, 7 => 1.0)
        @test get_initial_uptime(system) == Dict(
            3 => PowerSystems.INFINITE_TIME, 7 => PowerSystems.INFINITE_TIME
        )
        @test get_initial_downtime(system) == Dict(3 => 0.0, 7 => 0.0)
        @test get_ramp_rates(system) == Dict(3 => 0.25, 7 => 0.25)
    end

    @testset "API extensions" begin
        set_optimizer_attribute(fnm, "tol_obj", 1e-2)
        @test get_optimizer_attribute(fnm, "tol_obj") == 1e-2

        set_optimizer_attributes(fnm, "tol_obj" => 1e-3, "it_lim" => 10_000)
        @test get_optimizer_attribute(fnm, "tol_obj") == 1e-3
        @test get_optimizer_attribute(fnm, "it_lim") == 10_000

        optimize!(fnm)
        @test solve_time(fnm.model) > 0
    end
end
