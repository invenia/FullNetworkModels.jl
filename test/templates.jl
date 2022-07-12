# Test that templates build JuMP models with anonymous variables and constraints.
# This is important to performance, see:
# - https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/merge_requests/142
# - https://github.com/jump-dev/JuMP.jl/issues/2973
function test_no_names(fnm::FullNetworkModel)
    @test !JuMP.set_string_names_on_creation(fnm.model)
    @test !has_names(fnm)
end

@testset "Templates" begin
    highs_opt = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    @testset "unit_commitment" begin
        fnm = unit_commitment(MISO, TEST_SYSTEM)
        test_no_names(fnm)
        tests_thermal_variable(fnm, "p")
        tests_commitment(fnm)
        tests_startup_shutdown(fnm)
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_static_noload_cost(fnm)
        tests_static_startup_cost(fnm)
        tests_ancillary_costs(fnm)
        tests_ancillary_limits(fnm)
        tests_regulation_requirements(fnm)
        tests_operating_reserve_requirements(fnm)
        tests_ramp_rates(fnm)
        tests_energy_balance(fnm)
    end

    @testset "unit_commitment with soft ramps and no ramps" begin
        # Modify system so that hard ramp constraints result in infeasibility
        system_infeasible = deepcopy(TEST_SYSTEM)
        init_gen = get_initial_generation(system_infeasible)
        # Modify initial generation of unit 7
        init_gen[2] = 50.0

        fnm = unit_commitment(MISO, system_infeasible, highs_opt; relax_integrality=true)
        optimize!(fnm)
        # Should be infeasible
        @test termination_status(fnm.model) == TerminationStatusCode(2)

        # Now do the same with soft ramp constraints – should be feasible
        fnm_soft_ramps = unit_commitment(
            MISO, system_infeasible, highs_opt;
            relax_integrality=true, slack=:ramp_rates => 1e3
        )
        # Basic ramp rate tests with correct slack
        tests_ramp_rates(fnm_soft_ramps; slack=1e3)

        optimize!(fnm_soft_ramps)
        @test termination_status(fnm_soft_ramps.model) == TerminationStatusCode(1)
        obj_soft_ramps = objective_value(fnm_soft_ramps.model)

        # Now do the same for no ramp constraints - should be feasible and have a lower
        # objective value (since there's no penalty for violating soft constraints)
        fnm_no_ramps = unit_commitment(
            MISO, system_infeasible, highs_opt; relax_integrality=true, ramp_rates=false
        )
        test_no_names(fnm_no_ramps)
        optimize!(fnm_no_ramps)
        @test termination_status(fnm_no_ramps.model) == TerminationStatusCode(1)
        obj_no_ramps = objective_value(fnm_no_ramps.model)
        @test obj_no_ramps < obj_soft_ramps

        # Also explicitly check that `fnm_no_ramps` doesn't have any ramp constraints
        @test !has_constraint(fnm_no_ramps.model, :ramp_up)
        @test !has_constraint(fnm_no_ramps.model, :ramp_down)
        @test !has_constraint(fnm_no_ramps.model, :ramp_up_initial)
        @test !has_constraint(fnm_no_ramps.model, :ramp_regulation)
        @test !has_constraint(fnm_no_ramps.model, :ramp_spin_sup)

        @testset "bid results" begin
            # The MEC for the system is $6.25 and the bids are all $1/MW.
            # This means INC should be cleared but DEC and PSD should not, since INCs should
            # clear when below MEC and DECs/PSDs should clear when above MEC.
            @test all(==(0.01), value.(fnm_no_ramps.model[:inc]))
            @test all(==(0.0), value.(fnm_no_ramps.model[:dec]))
            @test all(==(0.0), value.(fnm_no_ramps.model[:psd]))
        end
    end

    @testset "unit_commitment(branch_flows=true)" begin
        fnm = unit_commitment(MISO, TEST_SYSTEM, highs_opt; branch_flows=true)
        test_no_names(fnm)
        tests_branch_flow_limits(UC, fnm)

        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj = objective_value(fnm.model)

        # Verify that the branch flows are within bounds
        mon_branches = filter(br -> br.is_monitored, get_branches(TEST_SYSTEM))
        mon_branches_names = string.(collect(keys(mon_branches)))

        @testset "branch flow limits" for c in TEST_CONTINGENCIES
            for m in mon_branches_names
                t_branch = get_branches(TEST_SYSTEM)[m]
                rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) <= rate
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) >= -rate
            end
        end

        # Modify the branch limits of the system slightly to activate the slack 1 for the
        # base case and contingency 2 (penalties are modified to make it cheaper than redispatching)
        system_sl1 = deepcopy(TEST_SYSTEM)
        branches = get_branches(system_sl1)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.135, 0.955, true, (100.0, 110.0), (1000.0, 2000.0)
        )
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 1 should be active in base-case and conting2 but not in conting1
        fnm = unit_commitment(MISO, system_sl1, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl1 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the branch rate, and SL1 is active
        @testset "branch bounds sl1 in base case and conting2" for c in ["base_case", "conting2"]
            m = "Transformer1"
            t_branch = get_branches(system_sl1)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0.0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0.0
        end

        # Modify the branch limits of the system slightly more to activate the slack 2 on
        # base-case and contingency 2. Also, activate slack 1 (but not slack 2) on contingency 1
        system_sl2 = deepcopy(TEST_SYSTEM)
        branches = get_branches(system_sl2)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.12, 0.27, true, (100.0, 110.0), (1000.0, 2000.0)
        )
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 2 should be active
        fnm = unit_commitment(MISO, system_sl2, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        @testset "branch bounds sl2 in base case and conting2" for c in ["base_case", "conting2"]
            m = "Transformer1"
            t_branch = get_branches(system_sl2)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) > 0
        end
        @testset "branch bounds sl1 in conting1" begin
            @test value.(fnm.model[:fl]["Transformer1",fnm.datetimes[1], "conting1"]) > transformer1_new.rate_b
            @test value.(fnm.model[:sl1_fl]["Transformer1",fnm.datetimes[1], "conting1"]) > 0.0
            @test value.(fnm.model[:sl2_fl]["Transformer1",fnm.datetimes[1], "conting1"]) == 0.0
        end

        # Modify the branch limits of the system to activate the all slack 2 for all scenarios
        system_sl2_all = deepcopy(TEST_SYSTEM)
        branches = get_branches(system_sl2_all)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.01, 0.05, true, (100.0, 110.0), (1000.0, 2000.0)
        )
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 2 should be active in all cases
        fnm = unit_commitment(MISO, system_sl2_all, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2_all = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        # in all cases SL1 should be at their maximum value
        @testset "branch bounds sl2 all cases" for c in TEST_CONTINGENCIES
            m = "Transformer1"
            t_branch = get_branches(system_sl2_all)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            tr1_sl1_max = (transformer1_new.break_points[2]-transformer1_new.break_points[1])*(rate/100)
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test isapprox(value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]), tr1_sl1_max)
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) > 0
        end

        #Compare objectives
        @test obj < obj_sl1
        @test obj_sl1 < obj_sl2
        @test obj_sl2 < obj_sl2_all

        # Test for branch flow limits without contingencies
        system_no_contingencies = deepcopy(TEST_SYSTEM)
        lodf = get_lodf(system_no_contingencies)
        delete!(lodf, "conting1")
        delete!(lodf, "conting2")

        fnm = unit_commitment(MISO, TEST_SYSTEM, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_no_conting = objective_value(fnm.model)
        @test obj_no_conting <= obj
    end

    @testset "economic_dispatch" begin
        fnm = economic_dispatch(MISO, TEST_SYSTEM_RT)
        test_no_names(fnm)
        tests_thermal_variable(fnm, "p")
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_ancillary_costs(fnm)
        tests_ancillary_limits(fnm)
        tests_regulation_requirements(fnm)
        tests_operating_reserve_requirements(fnm)
        tests_energy_balance(fnm)

        # Solve the original ED with slack = nothing
        fnm = economic_dispatch(MISO, TEST_SYSTEM_RT, highs_opt; slack=nothing)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_orig = objective_value(fnm.model)
        # Solve it with slack = 1e4
        fnm = economic_dispatch(MISO, TEST_SYSTEM_RT, highs_opt; slack=1e4)
        optimize!(fnm)
        # Should be feasible with a smaller objective value.
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_slack_1e4 = objective_value(fnm.model)

        # Modify system to increase Regulation requirements (infeasible system)
        system_infeasible = deepcopy(TEST_SYSTEM_RT)
        zones = get_zones(system_infeasible)
        delete!(zones, 1)
        zone1_new = Zone(1, 1e3, 0.3, 0.3)
        insert!(zones, 1, zone1_new)

        # Solve with no slack – should be infeasible
        fnm = economic_dispatch(MISO, system_infeasible, highs_opt; slack=nothing)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(2)
        # Solve with two different values of slack – should be feasible with different objectives
        fnm = economic_dispatch(MISO, system_infeasible, highs_opt; slack=1e2)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_low_slack = objective_value(fnm.model)
        fnm = economic_dispatch(MISO, system_infeasible, highs_opt; slack=1e4)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_high_slack = objective_value(fnm.model)

        # Check if objective values make sense – higher slack should mean higher objective
        @test obj_low_slack > obj_orig
        @test obj_high_slack > obj_low_slack
    end

    @testset "economic_dispatch(branch_flows=true)" begin
        fnm = economic_dispatch(MISO, TEST_SYSTEM_RT, highs_opt; branch_flows=true)
        test_no_names(fnm)
        tests_branch_flow_limits(ED, fnm)
        # Solve the original ED with thermal branch constraints
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj = objective_value(fnm.model)

        # Verify that the branch flows are within bounds
        mon_branches = filter(br -> br.is_monitored, get_branches(TEST_SYSTEM))
        mon_branches_names = string.(collect(keys(mon_branches)))
        @testset "branch bounds" for c in TEST_CONTINGENCIES
            for m in mon_branches_names
                t_branch = get_branches(TEST_SYSTEM_RT)[m]
                rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) <= rate
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) >= -rate
            end
        end

        # Modify the branch limits of the system slightly to activate the slack 1 for the
        # base case and contingency 2 (penalties are modified to make it cheaper than redispatching)
        system_sl1 = deepcopy(TEST_SYSTEM_RT)
        branches = get_branches(system_sl1)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.06, 0.955, true, (100.0, 110.0), (1000.0, 2000.0)
        ) # 0.149, 6.0
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 1 should be active in base-case and conting2 but not in conting1
        fnm = economic_dispatch(MISO, system_sl1, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl1 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the branch rate, and SL1 is active
        @testset "branch bounds sl1 in base case" begin
            m = "Transformer1"
            t_branch = get_branches(system_sl1)[m]
            rate = t_branch.rate_a
            @test value.(fnm.model[:fl][m, fnm.datetimes[end], "base_case"]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[end], "base_case"]) > 0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[end], "base_case"]) == 0
        end

        # Modify the branch limits of the system slightly more to activate the slack 2 on
        # base-case and contingency 2. Also, activate slack 1 (but not slack 2) on contingency 1
        system_sl2 = deepcopy(TEST_SYSTEM_RT)
        branches = get_branches(system_sl2)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.1, 0.2, true, (100.0, 110.0), (1000.0, 2000.0)
        ) # 0.11, 0.24
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 2 should be active
        fnm = economic_dispatch(MISO, system_sl2, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        @testset "branch bounds sl2 in base case and conting2" for c in TEST_CONTINGENCIES
            m = "Transformer1"
            t_branch = get_branches(system_sl2)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) > 0
        end

        # Modify the branch limits of the system to activate the all slack 2 for all scenarios
        system_sl2_all = deepcopy(TEST_SYSTEM_RT)
        branches = get_branches(system_sl2_all)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.01, 0.05, true, (100.0, 110.0), (1000.0, 2000.0)
        ) #0.01, 0.01
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 2 should be active in all cases
        fnm = economic_dispatch(MISO, system_sl2_all, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2_all = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        # in all cases SL1 should be at their maximum value
        @testset "branch bounds sl2 all cases" for c in TEST_CONTINGENCIES
            m = "Transformer1"
            t_branch = get_branches(system_sl2_all)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            tr1_sl1_max = (transformer1_new.break_points[2]-transformer1_new.break_points[1])*(rate/100)
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test isapprox(value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]), tr1_sl1_max)
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) > 0
        end

        #Compare objectives
        @test obj < obj_sl1
        @test obj_sl1 < obj_sl2
        @test obj_sl2 < obj_sl2_all

        # Modify the branch break-points to one breakpoint only and activate slack 1
        system_bkpt_one = deepcopy(TEST_SYSTEM_RT)
        branches = get_branches(system_bkpt_one)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.045, 0.1, true, (100.0, 0.0), (1000.0, 0.0)
        )
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, slack 1 should be active
        fnm = economic_dispatch(MISO, system_bkpt_one, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_bkpt_one = objective_value(fnm.model)

        @testset "branch bounds sl1 one breakpoint" for c in TEST_CONTINGENCIES
            m = "Transformer1"
            t_branch = get_branches(system_bkpt_one)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0.0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0
        end

        # Modify the branch break-points to zero break-points
        system_bkpt_zero = deepcopy(TEST_SYSTEM_RT)
        branches = get_branches(system_bkpt_zero)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 5.0, 6.0, true, (0.0, 0.0), (0.0, 0.0)
        )
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, should be feasible
        fnm = economic_dispatch(MISO, system_bkpt_zero, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_bkpt_zero = objective_value(fnm.model)

        @testset "branch bounds sl1 one breakpoint" for c in TEST_CONTINGENCIES
            m = "Transformer1"
            t_branch = get_branches(system_bkpt_zero)[m]
            rate = c == "base_case" ? t_branch.rate_a : t_branch.rate_b
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) < rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) == 0.0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0
        end

        # Modify the branch rate and zero break points to make it infeasible
        system_bkpt_inf = deepcopy(TEST_SYSTEM_RT)
        branches = get_branches(system_bkpt_inf)
        delete!(branches, "Transformer1")
        transformer1_new = Branch(
            "Transformer1", "Bus2", "Bus3", 0.045, 0.1, true, (0.0, 0.0), (0.0, 0.0)
        )
        insert!(branches, "Transformer1", transformer1_new)

        # Solve, should be infeasible
        fnm = economic_dispatch(MISO, system_bkpt_inf, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(2)

        # Test for branch flow limits without contingencies
        system_no_contingencies = deepcopy(TEST_SYSTEM_RT)
        lodf = get_lodf(system_no_contingencies)
        delete!(lodf, "conting1")
        delete!(lodf, "conting2")
        fnm = economic_dispatch(MISO, system_no_contingencies, highs_opt; branch_flows=true)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_no_conting = objective_value(fnm.model)
        @test obj_no_conting <= obj
    end

    @testset "Energy balance as soft constraint: $T" for (T, t_system, solver) in (
        (UC, TEST_SYSTEM, highs_opt),
        (ED, TEST_SYSTEM_RT, highs_opt)
    )
        datetimes=get_datetimes(t_system)
        # Run the original test system and get the optimised objective
        fnm = _simple_template(t_system, T, solver; slack=nothing)
        optimize!(fnm)
        # Save the objective (Should be feasible)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_ori = objective_value(fnm.model)

        # Modify system such that we get infeasibility by excess load
        system_infe_load = deepcopy(t_system)
        loads = get_load(system_infe_load)
        loads .= 10.0

        fnm_inf = _simple_template(system_infe_load, T, solver; slack=nothing)
        optimize!(fnm_inf)
        # Should be infeasible
        @test termination_status(fnm_inf.model) == TerminationStatusCode(2)

        # Now do the same with soft energy balance constraints – should be feasible
        fnm_soft_eb = _simple_template(system_infe_load, T, solver; slack=1e4)
        optimize!(fnm_soft_eb)
        @test termination_status(fnm_soft_eb.model) == TerminationStatusCode(1)
        obj_soft_eb = objective_value(fnm_soft_eb.model)
        @testset "$T Energy balance slack Active" for t in fnm.datetimes
            @test value.(fnm_soft_eb.model[:sl_eb_gen][t]) > 0.0
        end
        @test obj_ori < obj_soft_eb

        # Modify system so that hard energy balance results in infeasibility by Generation
        # Note: this test is only for ED since UC simply decommits generation and uses
        # the sl_eb_gen slack to compensate for the energy balance constraint. In the ED the
        # commitment status are fixed, so it forces the optimisation to use the sl_eb_load.
        if T == ED
            system_infe_gen = deepcopy(t_system)
            loads = get_load(system_infe_gen)
            loads .= 0.1

            fnm_inf = _simple_template(system_infe_gen, T, solver; slack=nothing)
            optimize!(fnm_inf)
            # Should be infeasible
            @test termination_status(fnm_inf.model) == TerminationStatusCode(2)

            # Now do the same with soft energy balance constraints – should be feasible
            fnm_soft_eb = _simple_template(system_infe_gen, T, solver; slack=1e4)
            optimize!(fnm_soft_eb)
            @test termination_status(fnm_soft_eb.model) == TerminationStatusCode(1)
            obj_soft_eb = objective_value(fnm_soft_eb.model)
            @testset "$T Energy balance slack Active" for t in fnm.datetimes
                @test value.(fnm_soft_eb.model[:sl_eb_load][t]) > 0.0
            end
            @test obj_ori < obj_soft_eb
        end
    end
end

# Test that templates don't error for a given `datetimes` argument
function test_templates(datetimes)
    solver = HiGHS.Optimizer
    uc = UnitCommitment()
    ed = EconomicDispatch()
    @test uc(MISO, TEST_SYSTEM, solver, datetimes) isa FullNetworkModel
    @test ed(MISO, TEST_SYSTEM_RT, solver, datetimes) isa FullNetworkModel
    @test unit_commitment(MISO, TEST_SYSTEM, solver, datetimes) isa FullNetworkModel
    @test economic_dispatch(MISO, TEST_SYSTEM_RT, solver, datetimes) isa FullNetworkModel
    return nothing
end

@testset "Templates defined for specific datetimes" begin
    datetimes = get_datetimes(TEST_SYSTEM)
    @testset "Array of datetimes" begin
        test_templates(datetimes[5:8])
    end
    @testset "StepRange of datetimes" begin
        test_templates(first(datetimes):Hour(1):last(datetimes))
    end
    @testset "Single datetime" begin
        # only need economic dispatch for a single datetime
        @test economic_dispatch(
            MISO, TEST_SYSTEM_RT, HiGHS.Optimizer, first(datetimes)
        ) isa FullNetworkModel
    end
end

@testset "Shift factor thresholding" begin
    solver = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    @testset "Unit commitment" begin
        system = deepcopy(TEST_SYSTEM)
        loads = get_load(system)
        loads("Load2_Bus3") .= loads("Load2_Bus3") .* 10.0 # increase load to induce congestion

        fnm = unit_commitment(MISO, system, solver; relax_integrality=true, branch_flows=true)
        optimize!(fnm)

        # Apply a threshold of 1.0, meaning that all shift factors will be zero
        fnm_thresh = unit_commitment(
            MISO, system, solver; relax_integrality=true, branch_flows=true, threshold=1.0
        )
        optimize!(fnm_thresh)

        # There is congestion due to high load
        @test any(!=(0), dual.(fnm.model[:branch_flow_max_base]))
        # No congestion since the shift factors were thresholded to zero
        @test all(==(0), dual.(fnm_thresh.model[:branch_flow_max_base]))
    end
    @testset "Economic dispatch" begin
        system = deepcopy(TEST_SYSTEM_RT)
        loads = get_load(system)
        loads .= loads .* 10.0 # increase load to induce congestion

        fnm = economic_dispatch(MISO, system, solver; branch_flows=true)
        set_silent(fnm.model) # to reduce test verbosity
        optimize!(fnm)

        # Apply a threshold of 1.0, meaning that all shift factors will be zero
        fnm_thresh = economic_dispatch(MISO, system, solver; branch_flows=true, threshold=1.0)
        set_silent(fnm_thresh.model) # to reduce test verbosity
        optimize!(fnm_thresh)

        # There is congestion due to high load
        @test any(!=(0), dual.(fnm.model[:branch_flow_max_base]))
        # No congestion since the shift factors were thresholded to zero
        @test all(==(0), dual.(fnm_thresh.model[:branch_flow_max_base]))
    end
end

# https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/issues/75
@testset "zero-arg constructors return callable structs" begin
    solver = HiGHS.Optimizer

    # test 3-arg method because it's the one called in FullNetworkSimulations._uc_day
    uc = UnitCommitment(ramp_rates=true, slack=:energy_balance => nothing)
    @test uc isa UnitCommitment
    fnm = uc(MISO, TEST_SYSTEM)
    @test haskey(fnm.model, :ramp_up)
    @test !haskey(fnm.model, :sl_eb_gen)

    uc = UnitCommitment(ramp_rates=false, slack=:energy_balance => 1e3)
    @test uc isa UnitCommitment
    fnm = uc(MISO, TEST_SYSTEM, solver)
    @test !haskey(fnm.model, :ramp_up)
    @test haskey(fnm.model, :sl_eb_gen)

    # Should accept (system,) or (system, solver) or (system, solver, datetimes)
    @test length(methods(uc)) == 3

    @test_throws Exception UnitCommitment(slack=:wrong => 1)
    @test_throws Exception UnitCommitment(slack=[:wrong => 1])

    datetime = first(get_datetimes(TEST_SYSTEM_RT))
    ed = EconomicDispatch(branch_flows=true, slack=:energy_balance => nothing)
    @test ed isa EconomicDispatch
    fnm = ed(MISO, TEST_SYSTEM_RT, solver, datetime)
    @test haskey(fnm.model, :branch_flows_base)
    @test !haskey(fnm.model, :sl_eb_gen)

    ed = EconomicDispatch(branch_flows=false, slack=:energy_balance => 1e3)
    @test ed isa EconomicDispatch
    fnm = ed(MISO, TEST_SYSTEM_RT, solver, datetime)
    @test !haskey(fnm.model, :branch_flows_base)
    @test haskey(fnm.model, :sl_eb_gen)
    # test `datetimes` argument correctly passed through
    @test fnm.datetimes == [datetime]

    @test_throws Exception EconomicDispatch(slack=:wrong => 1)
    @test_throws Exception EconomicDispatch(slack=[:wrong => 1])
end
