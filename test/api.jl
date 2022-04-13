@testset "API functions" begin

    @testset "Prints" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM)
        t1 = DateTime(2017, 12, 15)
        t2 = DateTime(2017, 12, 15, 23)
        @test sprint(show, fnm; context=:compact => true) == "FullNetworkModel{UC}($t1 … $t2)"
        @test sprint(show, fnm) == strip("""
            FullNetworkModel{UC}
            Time periods: $t1 to $t2
            System: 34 components
            Model formulation: 0 variables and 0 constraints
            """
        )
        var_commitment!(fnm)
        n_units = length(fnm.datetimes) * length(get_unit_codes(ThermalGen, fnm.system))
        @test sprint(show, fnm) == strip("""
            FullNetworkModel{UC}
            Time periods: $t1 to $t2
            System: 34 components
            Model formulation: $n_units variables and $n_units constraints
              Variable names: u
            """
        )
        con_must_run!(fnm)
        @test sprint(show, fnm) == strip("""
            FullNetworkModel{UC}
            Time periods: $t1 to $t2
            System: 34 components
            Model formulation: $n_units variables and $(2 * n_units) constraints
              Variable names: u
              Constraint names: must_run
            """
        )
    end

    @testset "Accessors" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM)
        fnm_rt = FullNetworkModel{ED}(TEST_SYSTEM_RT)
        t1 = DateTime(2017, 12, 15)
        t2 = DateTime(2017, 12, 15, 23)

        system = fnm.system
        system_rt = fnm_rt.system
        datetimes = fnm.datetimes
        n_periods = get_forecast_horizon(system)
        unit_codes = get_unit_codes(ThermalGen, system)
        @test issetequal(get_bus_names(system), ("Bus1", "Bus2", "Bus3"))

        @test issetequal(unit_codes, (7, 3))
        load_names = get_load_names(PowerLoad, system)
        @test issetequal(load_names, ("Load1_Bus2", "Load2_Bus3"))
        @test load_names isa Vector{<:AbstractString}

        @test @inferred(get_forecast_timestamps(system)) == t1:Hour(1):t2

        n_units = length(unit_codes)
        @test get_pmin(system) == DenseAxisArray(
            fill(0.5, n_units, n_periods), unit_codes, datetimes
        )
        @test get_pmax(system) == DenseAxisArray(
            fill(8.0, n_units, n_periods), unit_codes, datetimes
        )
        @test get_regmin(system) == DenseAxisArray(
            fill(0.5, n_units, n_periods), unit_codes, datetimes
        )
        @test get_regmax(system) == DenseAxisArray(
            fill(7.5, n_units, n_periods), unit_codes, datetimes
        )
        @test get_regulation_cost(system) == DenseAxisArray(
            vcat(fill(10_000, 1, n_periods), fill(20_000, 1, n_periods)),
            unit_codes,
            datetimes
        )
        @test get_commitment_status(system_rt) == DenseAxisArray(
            trues(n_units, n_periods), unit_codes, datetimes
        )
        @test get_commitment_reg_status(system_rt) == DenseAxisArray(
            trues(n_units, n_periods), unit_codes, datetimes
        )
        @test get_spinning_cost(system) == DenseAxisArray(
            vcat(fill(15_000, 1, n_periods), fill(30_000, 1, n_periods)),
            unit_codes,
            datetimes
        )
        @test get_on_sup_cost(system) == DenseAxisArray(
            vcat(fill(17_500, 1, n_periods), fill(35_000, 1, n_periods)),
            unit_codes,
            datetimes
        )
        @test get_off_sup_cost(system) == DenseAxisArray(
            vcat(fill(20_000, 1, n_periods), fill(40_000, 1, n_periods)),
            unit_codes,
            datetimes
        )
        @test get_offer_curves(system) == DenseAxisArray(
            vcat(
                fill([(400.0, 0.5), (600.0, 1.0), (625.0, 8.0)], 1, n_periods),
                fill([(600.0, 0.5), (800.0, 1.0), (825.0, 8.0)], 1, n_periods)
            ),
            unit_codes,
            datetimes
        )
        @test get_noload_cost(system) == DenseAxisArray(
            vcat(fill(100, 1, n_periods), fill(200, 1, n_periods)),
            unit_codes,
            datetimes
        )
        @test get_startup_cost(system) == DenseAxisArray(
            vcat(fill(150, 1, n_periods), fill(300, 1, n_periods)),
            unit_codes,
            datetimes
        )
        @test get_regulation_requirements(system) == Dict(
            1 => 0.3, 2 => 0.4, FNM.MARKET_WIDE_ZONE => 0.8
        )
        @test get_operating_reserve_requirements(system) == Dict(
            1 => 0.4, 2 => 0.5, FNM.MARKET_WIDE_ZONE => 1.2
        )
        @test issetequal(
            get_reserve_zones(system), (1, 2, FNM.MARKET_WIDE_ZONE)
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
        @test get_must_run_flag(system) == DenseAxisArray(
            zeros(2, n_periods), unit_codes, datetimes
        )
        @test get_availability(system) == DenseAxisArray(
            ones(2, n_periods), unit_codes, datetimes
        )

        @test get_unit_codes_perbus(ThermalGen, system) == Dict(
            "Bus1" => [3], "Bus2" => [7], "Bus3" => []
        )
        @test get_load_names_perbus(PowerLoad, system) == Dict(
            "Bus1" => [], "Bus2" => ["Load1_Bus2"], "Bus3" => ["Load2_Bus3"]
        )
        @test get_bid_names_perbus(Increment, system) == Dict(
            "Bus1" => ["111_Bus1"], "Bus2" => [], "Bus3" => []
        )
        @test get_bid_names_perbus(Decrement, system) == Dict(
            "Bus1" => ["222_Bus1"], "Bus2" => [], "Bus3" => []
        )
        @test get_bid_names_perbus(PriceSensitiveDemand, system) == Dict(
            "Bus1" => ["333_Bus1"], "Bus2" => [], "Bus3" => []
        )

        ptdf_mat = get_ptdf(system)
        @test ptdf_mat isa DenseAxisArray
        @test issetequal(axes(ptdf_mat, 1), ("Line1", "Line2", "Line3", "Transformer1"))
        @test issetequal(axes(ptdf_mat, 2), ("Bus1", "Bus2",  "Bus3"))
        th = FullNetworkModels._PTDF_THRESHOLD
        @test all(x -> x == 0 || abs(x) > th, get_ptdf(system))
        ptdf_mat_thresh = get_ptdf(system; threshold=0.05) # use a custom threshold
        @test all(x -> x == 0 || abs(x) > 0.05, get_ptdf(system))

        lodf_dict = get_lodf_dict(system)
        @test issetequal(keys(lodf_dict), ("conting1", "conting2"))
        @test eltype(values(lodf_dict)) == DenseAxisArray

        @testset "Get data for specific datetimes" begin
            datetimes = get_forecast_timestamps(system)[5:8]
            n_periods = length(datetimes)
            @test get_pmax(system, datetimes) == DenseAxisArray(
                fill(8.0, n_units, n_periods), unit_codes, datetimes
            )
            @test get_regmin(system, datetimes) == DenseAxisArray(
                fill(0.5, n_units, n_periods), unit_codes, datetimes
            )
            @test get_regmax(system, datetimes) == DenseAxisArray(
                fill(7.5, n_units, n_periods), unit_codes, datetimes
            )
            @test get_regulation_cost(system, datetimes) == DenseAxisArray(
                vcat(fill(10_000, 1, n_periods), fill(20_000, 1, n_periods)),
                unit_codes,
                datetimes
            )
        end
        @testset "Get monitored data" begin
            monitored_branches_names = get_monitored_branch_names(Branch, system)
            branches_break_points = get_branch_break_points(monitored_branches_names, system)
            branches_penalties = get_branch_penalties(monitored_branches_names, system)
            (branches_zero_break_points,
                branches_one_break_points,
                branches_two_break_points) = FNM._get_branch_num_break_points_names(Branch, system)
            @test issetequal(monitored_branches_names, ("Line1", "Line3", "Transformer1"))
            @test monitored_branches_names isa Vector{<:AbstractString}
            @test branches_break_points == Dict(
                "Transformer1" => [100.0, 110.0],
                "Line1" => [100.0, 110.0],
                "Line3" => [100.0, 110.0],
            )
            @test branches_penalties == Dict(
                "Transformer1" => [1e5, 2e5],
                "Line1" => [1e5, 2e5],
                "Line3" => [1e5, 2e5],
            )
            @test isempty(branches_zero_break_points)
            @test isempty(branches_one_break_points)
            @test issetequal(branches_two_break_points, ("Line1", "Line3", "Transformer1"))
        end
    end

    @testset "API extensions" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM)
        # test model has no solver
        @test solver_name(fnm.model) === solver_name(Model())

        set_optimizer(fnm, Clp.Optimizer)
        @test solver_name(fnm.model) == "Clp"

        set_optimizer_attribute(fnm, "PrimalTolerance", 1e-2)
        @test get_optimizer_attribute(fnm, "PrimalTolerance") == 1e-2

        set_optimizer_attributes(fnm, "PrimalTolerance" => 1e-3, "MaximumIterations" => 10_000)
        @test get_optimizer_attribute(fnm, "PrimalTolerance") == 1e-3
        @test get_optimizer_attribute(fnm, "MaximumIterations") == 10_000

        optimize!(fnm)
        @test solve_time(fnm.model) > 0
    end
end
