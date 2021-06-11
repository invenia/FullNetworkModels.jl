@testset "Internal utility functions" begin
    @testset "_generators_by_reserve_zone" begin
        zone_gens = FullNetworkModels._generators_by_reserve_zone(TEST_SYSTEM)
        @test zone_gens isa Dict
        @test zone_gens[1] == [3]
        @test zone_gens[2] == [7]
        @test issetequal(zone_gens[FullNetworkModels.MARKET_WIDE_ZONE], [3, 7])
        @test _get_resolution_in_minutes(TEST_SYSTEM) == 60
    end
end
