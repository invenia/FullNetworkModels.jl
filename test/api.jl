@testset "API functions" begin
    fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
    @testset "Prints" begin
        @test sprint(show, fnm) == "FullNetworkModel\nModel formulation: 0 variables\nSystem: 23 components, 24 time periods\n"
    end
    @testset "Getters" begin
        @test issetequal(get_unit_codes(ThermalGen, fnm.system), (7, 3))
        @test get_initial_time(fnm.system) == DateTime("2017-12-15T00:00:00")
        @test get_pmin(fnm.system)[7] == fill(0.5, 24)
        @test get_pmax(fnm.system)[7] == fill(5.0, 24)
        @test get_regmin(fnm.system)[7] == fill(1.0, 24)
        @test get_regmax(fnm.system)[7] == fill(4.5, 24)
        @test get_cost_regulation(fnm.system)[3] == fill(20_000, 24)
        @test get_cost_spinning(fnm.system)[3] == fill(30_000, 24)
        @test get_cost_supp_on(fnm.system)[3] == fill(35_000, 24)
        @test get_cost_supp_off(fnm.system)[3] == fill(40_000, 24)
    end
end
