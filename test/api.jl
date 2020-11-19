@testset "API functions" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "Prints" begin
        @test sprint(show, fnm) == "FullNetworkModel\nModel formulation: 0 variables\nSystem: 23 components, 24 time periods\n"
    end
    @testset "Getters" begin
        n_periods = get_forecasts_horizon(fnm.system)
        @test issetequal(get_unit_codes(ThermalGen, fnm.system), (7, 3))
        @test get_initial_time(fnm.system) == DateTime("2017-12-15T00:00:00")
        @test get_pmin(fnm.system) == Dict(
            3 => fill(0.5, n_periods), 7 => fill(0.5, n_periods)
        )
        @test get_pmax(fnm.system) == Dict(
            3 => fill(5.0, n_periods), 7 => fill(5.0, n_periods)
        )
        @test get_regmin(fnm.system) == Dict(
            3 => fill(1.0, n_periods), 7 => fill(1.0, n_periods)
        )
        @test get_regmax(fnm.system) == Dict(
            3 => fill(4.5, n_periods), 7 => fill(4.5, n_periods)
        )
        @test get_regulation_cost(fnm.system) == Dict(
            3 => fill(20_000, n_periods), 7 => fill(10_000, n_periods)
        )
        @test get_spinning_cost(fnm.system) == Dict(
            3 => fill(30_000, n_periods), 7 => fill(15_000, n_periods)
        )
        @test get_on_sup_cost(fnm.system) == Dict(
            3 => fill(35_000, n_periods), 7 => fill(17_500, n_periods)
        )
        @test get_off_sup_cost(fnm.system) == Dict(
            3 => fill(40_000, n_periods), 7 => fill(20_000, n_periods)
        )
        @test get_offer_curves(fnm.system) == Dict(
            3 => fill([(600.0, 0.5), (800.0, 1.0), (825.0, 5.0)], n_periods),
            7 => fill([(400.0, 0.5), (600.0, 1.0), (625.0, 5.0)], n_periods)
        )
        @test get_noload_cost(fnm.system) == Dict(
            3 => fill(200.0, n_periods), 7 => fill(100.0, n_periods)
        )
        @test get_startup_cost(fnm.system) == Dict(
            3 => fill(300.0, n_periods), 7 => fill(150.0, n_periods)
        )
    end
end
