@testset "API functions" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "Prints" begin
        @test sprint(show, fnm) == "FullNetworkModel\nModel formulation: 0 variables\nSystem: 23 components, 24 time periods\n"
    end
end

@testset "Structs" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "FullNetworkParams" begin
        @test issetequal(fnm.params.unit_codes, (7, 3))
        @test fnm.params.n_periods == 24
        @test fnm.params.initial_time == DateTime("2017-12-15T00:00:00")
        @testset "ForecastData" begin
            @test fnm.params.forecasts.active_power_min[7] == fill(0.5, 24)
            @test fnm.params.forecasts.active_power_max[7] == fill(5.0, 24)
            @test fnm.params.forecasts.regulation_min[7] == fill(1.0, 24)
            @test fnm.params.forecasts.regulation_max[7] == fill(4.5, 24)
            @test fnm.params.forecasts.cost_regulation[3] == fill(20_000, 24)
            @test fnm.params.forecasts.cost_spinning[3] == fill(30_000.0, 24)
            @test fnm.params.forecasts.cost_supp_on[3] == fill(35_000.0, 24)
            @test fnm.params.forecasts.cost_supp_off[3] == fill(40_000.0, 24)
        end
    end
end
