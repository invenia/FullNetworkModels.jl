@testset "Templates" begin
    @testset "unit_commitment" begin
        fnm = unit_commitment(TEST_SYSTEM, Cbc.Optimizer)
        datetimes = fnm.datetimes
        tests_thermal_variable(fnm, "p")
        tests_commitment(fnm)
        tests_startup_shutdown(fnm)
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_thermal_noload_cost(fnm)
        tests_thermal_startup_cost(fnm)
        tests_ancillary_costs(fnm)
        tests_ancillary_limits(fnm)
        tests_regulation_requirements(fnm)
        tests_operating_reserve_requirements(fnm)
        tests_ramp_rates(fnm)
        tests_energy_balance(fnm)
    end
    @testset "unit_commitment (soft_ramps) and unit_commitment_no_ramps" begin
        # Modify system so that hard ramp constraints result in infeasibility
        system_infeasible = deepcopy(TEST_SYSTEM)
        gens = collect(get_components(ThermalGen, system_infeasible))
        gens[1].active_power = 50.0
        @test get_initial_generation(system_infeasible)[7] == 50.0

        fnm = unit_commitment(system_infeasible, Cbc.Optimizer; relax_integrality=true)
        optimize!(fnm)
        # Should be infeasible (termination 6 because Cbc uses INFEASIBLE_OR_UNBOUNDED)
        @test termination_status(fnm.model) == TerminationStatusCode(6)

        # Now do the same with soft ramp constraints – should be feasible
        fnm_soft_ramps = unit_commitment_soft_ramps(
            system_infeasible, Cbc.Optimizer; slack=1e3, relax_integrality=true
        )
        # Basic ramp rate tests with correct slack
        tests_ramp_rates(fnm_soft_ramps; slack=1e3)

        optimize!(fnm_soft_ramps)
        @test termination_status(fnm_soft_ramps.model) == TerminationStatusCode(1)
        obj_soft_ramps = objective_value(fnm_soft_ramps.model)

        # Now do the same for no ramp constraints - should be feasible and have a lower
        # objective value (since there's no penalty for violating soft constraints)
        fnm_no_ramps = unit_commitment_no_ramps(
            system_infeasible, Cbc.Optimizer; relax_integrality=true
        )
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
    @testset "unit_commitment_branch_flow_limits" begin
        fnm = unit_commitment_branch_flow_limits(TEST_SYSTEM, Cbc.Optimizer)
        tests_branch_flow_limits(UC, fnm)

        # Solve the original UC with thermal branch constraints
        fnm = unit_commitment_branch_flow_limits(TEST_SYSTEM, Cbc.Optimizer)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj = objective_value(fnm.model)

        # Verify that the branch flows are within bounds
        monitored_branches_names = get_monitored_branch_names(Branch, TEST_SYSTEM)
        @testset "branch bounds" for c in TEST_SCENARIOS
            for m in monitored_branches_names
                t_branch = get_component(Branch, TEST_SYSTEM, m)
                rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) <= rate
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) >= -rate
            end
        end

        # Modify the branch limits of the system slightly to activate the slack 1 for the
        # base case and contingency 2 (penalties are modified to make it cheaper than redispatching)
        system_sl1 = deepcopy(TEST_SYSTEM)
        Transformer1 = get_component(Branch, system_sl1, "Transformer1")
        set_rate!(Transformer1, 0.135) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.955 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["penalties"] = [1000.0, 2000.0]

        # Solve, slack 1 should be active in base-case and conting2 but not in conting1
        fnm = unit_commitment_branch_flow_limits(system_sl1, Cbc.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl1 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the branch rate, and SL1 is active
        @testset "branch bounds sl1 in base case and conting2" for c in ["base_case", "conting2"]
            m = "Transformer1"
            t_branch = get_component(Branch, system_sl1, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0.0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0.0
        end

        # Modify the branch limits of the system slightly more to activate the slack 2 on
        # base-case and contingency 2. Also, activate slack 1 (but not slack 2) on contingency 1
        system_sl2 = deepcopy(TEST_SYSTEM)
        Transformer1 = get_component(Branch, system_sl2, "Transformer1")
        set_rate!(Transformer1, 0.12) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.27 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["penalties"] = [1000.0, 2000.0]

        # Solve, slack 2 should be active
        fnm = unit_commitment_branch_flow_limits(system_sl2, Cbc.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        @testset "branch bounds sl2 in base case and conting2" for c in ["base_case", "conting2"]
            m = "Transformer1"
            t_branch = get_component(Branch, system_sl2, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) > 0
        end
        @testset "branch bounds sl1 in conting1" begin
            @test value.(fnm.model[:fl]["Transformer1",fnm.datetimes[1], "conting1"]) > Transformer1.ext["rate_b"]
            @test value.(fnm.model[:sl1_fl]["Transformer1",fnm.datetimes[1], "conting1"]) > 0.0
            @test value.(fnm.model[:sl2_fl]["Transformer1",fnm.datetimes[1], "conting1"]) == 0.0
        end

        # Modify the branch limits of the system to activate the all slack 2 for all scenarios
        system_sl2_all = deepcopy(TEST_SYSTEM)
        Transformer1 = get_component(Branch, system_sl2_all, "Transformer1")
        set_rate!(Transformer1, 0.01) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.05 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["penalties"] = [1000.0, 2000.0]

        # Solve, slack 2 should be active in all cases
        fnm = unit_commitment_branch_flow_limits(system_sl2_all, Cbc.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2_all = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        # in all cases SL1 should be at their maximum value
        @testset "branch bounds sl2 all cases" for c in TEST_SCENARIOS
            m = "Transformer1"
            t_branch = get_component(Branch, system_sl2_all, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            tr1_sl1_max = (Transformer1.ext["break_points"][2]-Transformer1.ext["break_points"][1])*(rate/100)
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
        lodf_device = only(get_components(LODFDict, system_no_contingencies))
        lodf_device.lodf_dict = Dict{String, DenseAxisArray}()
        fnm = unit_commitment_branch_flow_limits(TEST_SYSTEM, Cbc.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_no_conting = objective_value(fnm.model)

        # Compare objectives without and with contingencies
        @test obj_no_conting <= obj
    end

    @testset "economic_dispatch" begin
        fnm = economic_dispatch(TEST_SYSTEM_RT, Clp.Optimizer)
        tests_thermal_variable(fnm, "p")
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_ancillary_costs(fnm)
        tests_ancillary_limits(fnm)
        tests_regulation_requirements(fnm)
        tests_operating_reserve_requirements(fnm)
        tests_energy_balance(fnm)

        # Solve the original ED with slack = nothing
        fnm = economic_dispatch(TEST_SYSTEM_RT, Clp.Optimizer; slack = nothing)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_orig = objective_value(fnm.model)
        # Solve it with slack = 1e4
        fnm = economic_dispatch(TEST_SYSTEM_RT, Clp.Optimizer; slack = 1e4)
        optimize!(fnm)
        # Should be feasible with a smaller objective value.
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_slack_1e4 = objective_value(fnm.model)

        # Modify system to increase Regulation requirements (infeasible system)
        system_infeasible = deepcopy(TEST_SYSTEM_RT)
        reg_1 = get_component(Service, system_infeasible, "regulation_1")
        set_requirement!(reg_1, 1e3)
        @test reg_1.requirement == 1e3

        # Solve with no slack – should be infeasible
        fnm = economic_dispatch(system_infeasible, Clp.Optimizer; slack=nothing)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(2)
        # Solve with two different values of slack – should be feasible with different objectives
        fnm = economic_dispatch(system_infeasible, Clp.Optimizer; slack=1e2)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_low_slack = objective_value(fnm.model)
        fnm = economic_dispatch(system_infeasible, Clp.Optimizer; slack=1e4)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_high_slack = objective_value(fnm.model)

        # Check if objective values make sense – higher slack should mean higher objective
        @test obj_low_slack > obj_orig
        @test obj_high_slack > obj_low_slack
    end
    @testset "economic_dispatch_branch_flow_limits" begin
        fnm = economic_dispatch_branch_flow_limits(TEST_SYSTEM_RT, Clp.Optimizer)
        tests_branch_flow_limits(ED, fnm)

        # Solve the original ED with thermal branch constraints
        fnm = economic_dispatch_branch_flow_limits(TEST_SYSTEM_RT, Clp.Optimizer)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj = objective_value(fnm.model)

        # Verify that the branch flows are within bounds
        monitored_branches_names = get_monitored_branch_names(Branch, TEST_SYSTEM_RT)
        @testset "branch bounds" for c in TEST_SCENARIOS
            for m in monitored_branches_names
                t_branch = get_component(Branch, TEST_SYSTEM_RT, m)
                rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) <= rate
                @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) >= -rate
            end
        end

        # Modify the branch limits of the system slightly to activate the slack 1 for the
        # base case and contingency 2 (penalties are modified to make it cheaper than redispatching)
        system_sl1 = deepcopy(TEST_SYSTEM_RT)
        Transformer1 = get_component(Branch, system_sl1, "Transformer1")
        set_rate!(Transformer1, 0.149) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.955 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["penalties"] = [1000.0, 2000.0]

        # Solve, slack 1 should be active in base-case and conting2 but not in conting1
        fnm = economic_dispatch_branch_flow_limits(system_sl1, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl1 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the branch rate, and SL1 is active
        @testset "branch bounds sl1 in base case and conting2" for c in ["base_case", "conting2"]
            m = "Transformer1"
            t_branch = get_component(Branch, system_sl1, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0
        end

        # Modify the branch limits of the system slightly more to activate the slack 2 on
        # base-case and contingency 2. Also, activate slack 1 (but not slack 2) on contingency 1
        system_sl2 = deepcopy(TEST_SYSTEM_RT)
        Transformer1 = get_component(Branch, system_sl2, "Transformer1")
        set_rate!(Transformer1, 0.11) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.24 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["penalties"] = [1000.0, 2000.0]

        # Solve, slack 2 should be active
        fnm = economic_dispatch_branch_flow_limits(system_sl2, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        @testset "branch bounds sl2 in base case and conting2" for c in ["base_case", "conting2"]
            m = "Transformer1"
            t_branch = get_component(Branch, system_sl2, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) > 0
        end
        @testset "branch bounds sl1 in conting1" begin
            @test value.(fnm.model[:fl]["Transformer1",fnm.datetimes[1], "conting1"]) > Transformer1.ext["rate_b"]
            @test value.(fnm.model[:sl1_fl]["Transformer1",fnm.datetimes[1], "conting1"]) > 0.0
            @test value.(fnm.model[:sl2_fl]["Transformer1",fnm.datetimes[1], "conting1"]) == 0.0
        end

        # Modify the branch limits of the system to activate the all slack 2 for all scenarios
        system_sl2_all = deepcopy(TEST_SYSTEM_RT)
        Transformer1 = get_component(Branch, system_sl2_all, "Transformer1")
        set_rate!(Transformer1, 0.01) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.05 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["penalties"] = [1000.0, 2000.0]

        # Solve, slack 2 should be active in all cases
        fnm = economic_dispatch_branch_flow_limits(system_sl2_all, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2_all = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        # in all cases SL1 should be at their maximum value
        @testset "branch bounds sl2 all cases" for c in TEST_SCENARIOS
            m = "Transformer1"
            t_branch = get_component(Branch, system_sl2_all, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            tr1_sl1_max = (Transformer1.ext["break_points"][2]-Transformer1.ext["break_points"][1])*(rate/100)
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
        Transformer1 = get_component(Branch, system_bkpt_one, "Transformer1")
        set_rate!(Transformer1, 0.045) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.1 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["break_points"] = [100.0]
        Transformer1.ext["penalties"] = [1000.0]

        # Solve, slack 1 should be active
        fnm = economic_dispatch_branch_flow_limits(system_bkpt_one, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_bkpt_one = objective_value(fnm.model)

        @testset "branch bounds sl1 one breakpoint" for c in TEST_SCENARIOS
            m = "Transformer1"
            t_branch = get_component(Branch, system_bkpt_one, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) > rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) > 0.0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0
        end

        # Modify the branch break-points to zero break-points
        system_bkpt_zero = deepcopy(TEST_SYSTEM_RT)
        Transformer1 = get_component(Branch, system_bkpt_zero, "Transformer1")
        Transformer1.ext["break_points"] = []
        Transformer1.ext["penalties"] = []

        # Solve, should be feasible
        fnm = economic_dispatch_branch_flow_limits(system_bkpt_zero, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_bkpt_zero = objective_value(fnm.model)

        @testset "branch bounds sl1 one breakpoint" for c in TEST_SCENARIOS
            m = "Transformer1"
            t_branch = get_component(Branch, system_bkpt_zero, m)
            rate = c == "base_case" ? t_branch.rate : t_branch.ext["rate_b"]
            @test value.(fnm.model[:fl][m, fnm.datetimes[1], c]) < rate
            @test value.(fnm.model[:sl1_fl][m, fnm.datetimes[1], c]) == 0.0
            @test value.(fnm.model[:sl2_fl][m, fnm.datetimes[1], c]) == 0
        end

        # Modify the branch rate and zero break points to make it infeasible
        system_bkpt_inf = deepcopy(TEST_SYSTEM_RT)
        Transformer1 = get_component(Branch, system_bkpt_inf, "Transformer1")
        set_rate!(Transformer1, 0.045) #Original flow 0.15
        Transformer1.ext["rate_b"] = 0.1 #Original flow conting1: 0.3, conting2: 1.0
        Transformer1.ext["break_points"] = []
        Transformer1.ext["penalties"] = []

        # Solve, should be infeasible
        fnm = economic_dispatch_branch_flow_limits(system_bkpt_inf, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(2)

        # Test for branch flow limits without contingencies
        system_no_contingencies = deepcopy(TEST_SYSTEM_RT)
        lodf_device = only(get_components(LODFDict, system_no_contingencies))
        lodf_device.lodf_dict = Dict{String, DenseAxisArray}()
        fnm = economic_dispatch_branch_flow_limits(system_no_contingencies, Clp.Optimizer)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_no_conting = objective_value(fnm.model)

        # Compare objectives without and with contingencies
        @test obj_no_conting <= obj
    end
    @testset "Soft Energy Balance: $T" for (T, t_system, solver) in (
        (UC, TEST_SYSTEM, Cbc.Optimizer),
        (ED, TEST_SYSTEM_RT, Clp.Optimizer)
    )
        datetimes=get_forecast_timestamps(t_system)
        # Run the original test system and get the optimised objective
        fnm = _simple_template(t_system, T, solver; slack=nothing)
        optimize!(fnm)
        # Save the objective (Should be feasible)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_ori = objective_value(fnm.model)

        # Modify system so that hard energy balance results in infeasibility by Load
        system_infe_load = deepcopy(t_system)
        loads = collect(get_components(PowerLoad, system_infe_load))
        set_active_power!(loads[1], 10.0)
        set_active_power!(loads[2], 10.0)

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
            loads = collect(get_components(PowerLoad, system_infe_gen))
            set_active_power!(loads[1], 0.1)
            set_active_power!(loads[2], 0.1)

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
    for template in (unit_commitment, unit_commitment_no_ramps)
        @test template(TEST_SYSTEM, Cbc.Optimizer, datetimes) isa FullNetworkModel
    end
    for template in (economic_dispatch, )
        @test template(TEST_SYSTEM_RT, Clp.Optimizer, datetimes) isa FullNetworkModel
    end
    return nothing
end

@testset "Templates defined for specific datetimes" begin
    datetimes = get_forecast_timestamps(TEST_SYSTEM)
    @testset "Array of datetimes" begin
        test_templates(datetimes[5:8])
    end
    @testset "StepRange of datetimes" begin
        test_templates(first(datetimes):Hour(1):last(datetimes))
    end
    @testset "Single datetime" begin
        test_templates(first(datetimes))
    end
end
