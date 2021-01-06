@testset "API functions" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "Prints" begin
        @test sprint(show, fnm) == "FullNetworkModel\nModel formulation: 0 variables\nSystem: 23 components, 24 time periods\n"
    end
    @testset "Getters" begin
        system = fnm.system
        n_periods = get_forecasts_horizon(system)
        @test issetequal(get_unit_codes(ThermalGen, system), (7, 3))
        @test issetequal(get_load_names(PowerLoad, system), ("Load1", "Load2"))
        @test get_initial_time(system) == DateTime("2017-12-15T00:00:00")
        @test get_pmin(system) == Dict(
            3 => fill(0.5, n_periods), 7 => fill(0.5, n_periods)
        )
        @test get_pmax(system) == Dict(
            3 => fill(5.0, n_periods), 7 => fill(5.0, n_periods)
        )
        @test get_regmin(system) == Dict(
            3 => fill(1.0, n_periods), 7 => fill(1.0, n_periods)
        )
        @test get_regmax(system) == Dict(
            3 => fill(4.5, n_periods), 7 => fill(4.5, n_periods)
        )
        @test get_regulation_cost(system) == Dict(
            3 => fill(20_000, n_periods), 7 => fill(10_000, n_periods)
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
            1 => 0.05, 2 => 0.1, FullNetworkModels.MARKET_WIDE_ZONE => 0.16
        )
        @test get_operating_reserve_requirements(system) == Dict(
            1 => 0.1, 2 => 0.15, FullNetworkModels.MARKET_WIDE_ZONE => 0.21
        )
        @test issetequal(
            get_reserve_zones(system), (1, 2, FullNetworkModels.MARKET_WIDE_ZONE)
        )
        @test get_initial_generation(system) == Dict(3 => 0.0, 7 => 0.0)
        @test get_initial_commitment(system) == Dict(3 => 0.0, 7 => 0.0)
        @test get_minimum_uptime(system) == Dict(3 => 3.0, 7 => 3.0)
        @test get_minimum_downtime(system) == Dict(3 => 3.0, 7 => 3.0)
        @test get_initial_uptime(system) == Dict(3 => 0.0, 7 => 0.0)
        @test get_initial_downtime(system) == Dict(
            3 => PowerSystems.INFINITE_TIME, 7 => PowerSystems.INFINITE_TIME
        )
        @test get_ramp_rates(system) == Dict(3 => 0.02, 7 => 0.02)
    end
end
