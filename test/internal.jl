@testset "Internal utility functions" begin
    @testset "_generators_by_reserve_zone" begin
        zone_gens = FNM._generators_by_reserve_zone(TEST_SYSTEM)
        @test zone_gens isa Dict
        @test zone_gens[1] == [3]
        @test zone_gens[2] == [7]
        @test issetequal(zone_gens[FNM.MARKET_WIDE_ZONE], [3, 7])
        @test FNM._get_resolution_in_minutes(TEST_SYSTEM) == 60
    end
    @testset "_add_to_objective!" begin
        model = Model(Clp.Optimizer)
        @variable(model, x[1:5] >= 0)
        @objective(model, Min, sum(x))
        expr = 2 * x[3]
        FNM._add_to_objective!(model, expr)
        @test objective_function(model) == sum(x) + expr
    end
    @testset "_variable_cost" begin
        system, _ = fake_3bus_system(MISO, DA; n_periods=2)
        fnm = unit_commitment(system, Cbc.Optimizer)
        unit_codes = get_unit_codes(ThermalGen, fnm.system)
        offer_curves = get_offer_curves(fnm.system)
        Λ, block_lims, n_blocks = FNM._curve_properties(offer_curves)
        thermal_cost = FNM._variable_cost(
            fnm.model, unit_codes, fnm.datetimes, n_blocks, Λ, :p, 1
        )
        p_aux = fnm.model[:p_aux]
        t1, t2 = fnm.datetimes[1:2]
        # Generators 3 and 7 have offer curves with prices and [600, 800, 825]
        # [400, 600, 625], respectively.
        # https://gitlab.invenia.ca/invenia/research/FullNetworkDataPrep.jl/-/blob/16f570e9116d86a2ce65e2e08aa702cefa268cc5/src/testutils.jl#L122
        @test thermal_cost ==
            600 * p_aux[3, t1, 1] + 800 * p_aux[3, t1, 2] + 825 * p_aux[3, t1, 3] +
            600 * p_aux[3, t2, 1] + 800 * p_aux[3, t2, 2] + 825 * p_aux[3, t2, 3] +
            400 * p_aux[7, t1, 1] + 600 * p_aux[7, t1, 2] + 625 * p_aux[7, t1, 3] +
            400 * p_aux[7, t2, 1] + 600 * p_aux[7, t2, 2] + 625 * p_aux[7, t2, 3]
    end
    @testset "_expand_slacks" begin
        soft_constraints = [:energy_balance, :ramp_rates, :ancillary_requirements]
        @test _expand_slacks(nothing) == Dict(soft_constraints .=> nothing)
        @test _expand_slacks(1e3) == Dict(soft_constraints .=> 1e3)
        @test _expand_slacks([:energy_balance => 1e3]) == Dict(
            :energy_balance => 1e3, :ramp_rates => nothing, :ancillary_requirements => nothing
        )
        @test _expand_slacks(:energy_balance => 1e3) == Dict(
            :energy_balance => 1e3, :ramp_rates => nothing, :ancillary_requirements => nothing
        )
        @test _expand_slacks([:energy_balance => nothing, :ramp_rates => 1e3]) == Dict(
            :energy_balance => nothing, :ramp_rates => 1e3, :ancillary_requirements => nothing
        )
    end
end
