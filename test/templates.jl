@testset "Templates" begin
    @testset "unit_commitment" begin
        fnm = unit_commitment(TEST_SYSTEM, GLPK.Optimizer)
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
    @testset "unit_commitment_soft_ramps and unit_commitment_no_ramps" begin
        # Modify system so that hard ramp constraints result in infeasibility
        system_infeasible = deepcopy(TEST_SYSTEM)
        gens = collect(get_components(ThermalGen, system_infeasible))
        gens[1].active_power = 50.0
        @test get_initial_generation(system_infeasible)[7] == 50.0

        fnm = unit_commitment(system_infeasible, GLPK.Optimizer; relax_integrality=true)
        optimize!(fnm)
        # Should be infeasible
        @test termination_status(fnm.model) == TerminationStatusCode(2)

        # Now do the same with soft ramp constraints – should be feasible
        fnm_soft_ramps = unit_commitment_soft_ramps(
            system_infeasible, GLPK.Optimizer; slack=1e3, relax_integrality=true
        )
        # Basic ramp rate tests with correct slack
        tests_ramp_rates(fnm_soft_ramps; slack=1e3)

        optimize!(fnm_soft_ramps)
        @test termination_status(fnm_soft_ramps.model) == TerminationStatusCode(1)
        obj_soft_ramps = objective_value(fnm_soft_ramps.model)

        # Now do the same for no ramp constraints - should be feasible and have a lower
        # objective value (since there's no penalty for violating soft constraints)
        fnm_no_ramps = unit_commitment_no_ramps(
            system_infeasible, GLPK.Optimizer; relax_integrality=true
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
        fnm = unit_commitment_branch_flow_limits(TEST_SYSTEM, GLPK.Optimizer, TEST_PTDF)
        tests_branch_flow_limits(UC, fnm, TEST_PTDF)

        # Solve the original UC with thermal branch constraints
        system_orig = deepcopy(TEST_SYSTEM)
        fnm = unit_commitment_branch_flow_limits(system_orig, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj = objective_value(fnm.model)

        # Verify that the branch flows are within bounds
        Line1 = get_component(Branch, system_orig, "Line1")
        Line3 = get_component(Branch, system_orig, "Line3")
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) <= Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) <= Line3.rate
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) >= -Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) >= -Line3.rate

        # Modify the branch limits of the system slightly to activate the slack 1
        system_sl1 = deepcopy(TEST_SYSTEM)
        Line1 = get_component(Branch, system_sl1, "Line1")
        Line3 = get_component(Branch, system_sl1, "Line3")
        set_rate!(Line1, 0.23) #Original flow 0.3
        set_rate!(Line3, 0.54) #Original flow 0.58

        # Solve, slack 1 should be active
        fnm = unit_commitment_branch_flow_limits(system_sl1, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl1 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, and SL1 is active
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) > Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) > Line3.rate
        @test value.(fnm.model[:sl1_fl0]["Line1",fnm.datetimes[1]]) > 0
        @test value.(fnm.model[:sl1_fl0]["Line3",fnm.datetimes[1]]) > 0
        @test value.(fnm.model[:sl2_fl0]["Line1",fnm.datetimes[1]]) == 0
        @test value.(fnm.model[:sl2_fl0]["Line3",fnm.datetimes[1]]) == 0

        # Modify the branch limits of the system slightly more to activate the slack 2
        system_sl2 = deepcopy(TEST_SYSTEM)
        Line1 = get_component(Branch, system_sl2, "Line1")
        Line3 = get_component(Branch, system_sl2, "Line3")
        set_rate!(Line1, 0.1) #Original flow 0.3
        set_rate!(Line3, 0.3) #Original flow 0.58

        # Solve, slack 2 should be active
        fnm = unit_commitment_branch_flow_limits(system_sl2, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        Line1_sl1_max = (Line1.ext["break_points"][2]-Line1.ext["break_points"][1])*(Line1.rate/100)
        Line3_sl1_max = (Line3.ext["break_points"][2]-Line3.ext["break_points"][1])*(Line3.rate/100)
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) > Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) > Line3.rate
        @test value.(fnm.model[:sl1_fl0]["Line1",fnm.datetimes[1]]) == Line1_sl1_max
        @test value.(fnm.model[:sl1_fl0]["Line3",fnm.datetimes[1]]) == Line3_sl1_max
        @test value.(fnm.model[:sl2_fl0]["Line1",fnm.datetimes[1]]) > 0.0
        @test value.(fnm.model[:sl2_fl0]["Line3",fnm.datetimes[1]]) > 0.0

        # Compare objectives - the use of slacks increases the objective value
        @test obj < obj_sl1
        @test obj_sl1 < obj_sl2

    end

    @testset "economic_dispatch" begin
        fnm = economic_dispatch(TEST_SYSTEM_RT, GLPK.Optimizer)
        tests_thermal_variable(fnm, "p")
        tests_generation_limits(fnm)
        tests_thermal_variable_cost(fnm)
        tests_ancillary_costs(fnm)
        tests_ancillary_limits(fnm)
        tests_regulation_requirements(fnm)
        tests_operating_reserve_requirements(fnm)
        tests_energy_balance(fnm)

        # Solve the original ED with slack = nothing
        system_orig = TEST_SYSTEM_RT
        fnm = economic_dispatch(system_orig, GLPK.Optimizer; slack = nothing)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_orig = objective_value(fnm.model)
        # Solve it with slack = 1e4
        fnm = economic_dispatch(system_orig, GLPK.Optimizer; slack = 1e4)
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
        fnm = economic_dispatch(system_infeasible, GLPK.Optimizer; slack=nothing)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(2)
        # Solve with two different values of slack – should be feasible with different objectives
        fnm = economic_dispatch(system_infeasible, GLPK.Optimizer; slack=1e2)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_low_slack = objective_value(fnm.model)
        fnm = economic_dispatch(system_infeasible, GLPK.Optimizer; slack=1e4)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_high_slack = objective_value(fnm.model)

        # Check if objective values make sense – higher slack should mean higher objective
        @test obj_low_slack > obj_orig
        @test obj_high_slack > obj_low_slack
    end
    @testset "economic_dispatch_branch_flow_limits" begin
        fnm = economic_dispatch_branch_flow_limits(TEST_SYSTEM_RT, GLPK.Optimizer, TEST_PTDF)
        tests_branch_flow_limits(ED, fnm, TEST_PTDF)

        # Solve the original ED with thermal branch constraints
        system_orig = TEST_SYSTEM_RT
        fnm = economic_dispatch_branch_flow_limits(system_orig, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        # Should be feasible
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj = objective_value(fnm.model)

        # Verify that the branch flows are within bounds
        Line1 = get_component(Branch, system_orig, "Line1")
        Line3 = get_component(Branch, system_orig, "Line3")
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) <= Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) <= Line3.rate
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) >= -Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) >= -Line3.rate

        # Modify the branch limits of the system slightly to activate the slack 1
        system_sl1 = deepcopy(TEST_SYSTEM_RT)
        Line1 = get_component(Branch, system_sl1, "Line1")
        Line3 = get_component(Branch, system_sl1, "Line3")
        set_rate!(Line1, 0.06) #Original flow 0.25
        set_rate!(Line3, 0.43) #Original flow 0.55

        # Solve, slack 1 should be active
        fnm = economic_dispatch_branch_flow_limits(system_sl1, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl1 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, and SL1 is active
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) > Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) > Line3.rate
        @test value.(fnm.model[:sl1_fl0]["Line1",fnm.datetimes[1]]) > 0
        @test value.(fnm.model[:sl1_fl0]["Line3",fnm.datetimes[1]]) > 0
        @test value.(fnm.model[:sl2_fl0]["Line1",fnm.datetimes[1]]) == 0
        @test value.(fnm.model[:sl2_fl0]["Line3",fnm.datetimes[1]]) == 0

        # Modify the branch limits of the system slightly more to activate the slack 2
        system_sl2 = deepcopy(TEST_SYSTEM_RT)
        Line1 = get_component(Branch, system_sl2, "Line1")
        Line3 = get_component(Branch, system_sl2, "Line3")
        set_rate!(Line1, 0.045) #Original flow 0.25
        set_rate!(Line3, 0.3) #Original flow 0.55

        # Solve, slack 2 should be active
        fnm = economic_dispatch_branch_flow_limits(system_sl2, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_sl2 = objective_value(fnm.model)

        # Verify that the branch flows are higher than the line rate, SL1 and SL2 are active
        Line1 = get_component(Branch, system_sl2, "Line1")
        Line3 = get_component(Branch, system_sl2, "Line3")
        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) > Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) > Line3.rate
        @test value.(fnm.model[:sl1_fl0]["Line1",fnm.datetimes[1]]) > 0.0
        @test value.(fnm.model[:sl1_fl0]["Line3",fnm.datetimes[1]]) > 0.0
        @test value.(fnm.model[:sl2_fl0]["Line1",fnm.datetimes[1]]) > 0.0
        @test value.(fnm.model[:sl2_fl0]["Line3",fnm.datetimes[1]]) > 0.0

        #Compare objectives
        @test obj < obj_sl1
        @test obj_sl1 < obj_sl2

        # Modify the branch breakpoints to one breakpoint only and activate slack 1
        system_bkpt_one = deepcopy(TEST_SYSTEM_RT)
        Line1 = get_component(Branch, system_bkpt_one, "Line1")
        Line3 = get_component(Branch, system_bkpt_one, "Line3")
        set_rate!(Line1, 0.045) #Original flow 0.25
        set_rate!(Line3, 0.3) #Original flow 0.55
        Line1.ext["break_points"] = [100.0]
        Line1.ext["penalties"] = [100000.0]
        Line3.ext["break_points"] = [100.0]
        Line3.ext["penalties"] = [100000.0]

        # Solve, slack 1 should be active
        fnm = economic_dispatch_branch_flow_limits(system_bkpt_one, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_bkpt_one = objective_value(fnm.model)

        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) > Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) > Line3.rate
        @test value.(fnm.model[:sl1_fl0]["Line1",fnm.datetimes[1]]) > 0.0
        @test value.(fnm.model[:sl1_fl0]["Line3",fnm.datetimes[1]]) > 0.0
        @test value.(fnm.model[:sl2_fl0]["Line1",fnm.datetimes[1]]) == 0.0
        @test value.(fnm.model[:sl2_fl0]["Line3",fnm.datetimes[1]]) == 0.0

        # Modify the branch breakpoints to zero breakpoints
        system_bkpt_zero = deepcopy(TEST_SYSTEM_RT)
        Line1 = get_component(Branch, system_bkpt_zero, "Line1")
        Line3 = get_component(Branch, system_bkpt_zero, "Line3")
        Line1.ext["break_points"] = []
        Line1.ext["penalties"] = []
        Line3.ext["break_points"] = []
        Line3.ext["penalties"] = []

        # Solve, should be feasible
        fnm = economic_dispatch_branch_flow_limits(system_bkpt_zero, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(1)
        obj_bkpt_zero = objective_value(fnm.model)

        @test value.(fnm.model[:fl0]["Line1",fnm.datetimes[1]]) <= Line1.rate
        @test value.(fnm.model[:fl0]["Line3",fnm.datetimes[1]]) <= Line3.rate
        @test value.(fnm.model[:sl1_fl0]["Line1",fnm.datetimes[1]]) == 0.0
        @test value.(fnm.model[:sl1_fl0]["Line3",fnm.datetimes[1]]) == 0.0
        @test value.(fnm.model[:sl2_fl0]["Line1",fnm.datetimes[1]]) == 0.0
        @test value.(fnm.model[:sl2_fl0]["Line3",fnm.datetimes[1]]) == 0.0

        # Modify the branch rate and zero break points to make it infeasible
        system_bkpt_inf = deepcopy(TEST_SYSTEM_RT)
        Line1 = get_component(Branch, system_bkpt_inf, "Line1")
        Line3 = get_component(Branch, system_bkpt_inf, "Line3")
        set_rate!(Line1, 0.045) #Original flow 0.25
        set_rate!(Line3, 0.3) #Original flow 0.55
        Line1.ext["break_points"] = []
        Line1.ext["penalties"] = []
        Line3.ext["break_points"] = []
        Line3.ext["penalties"] = []

        # Solve, should be infeasible
        fnm = economic_dispatch_branch_flow_limits(system_bkpt_inf, GLPK.Optimizer, TEST_PTDF)
        optimize!(fnm)
        @test termination_status(fnm.model) == TerminationStatusCode(2)

    end
end

# Test that templates don't error for a given `datetimes` argument
function test_templates(datetimes)
    for template in (unit_commitment, unit_commitment_no_ramps, unit_commitment_soft_ramps)
        @test template(TEST_SYSTEM, GLPK.Optimizer, datetimes) isa FullNetworkModel
    end
    for template in (economic_dispatch, )
        @test template(TEST_SYSTEM_RT, GLPK.Optimizer, datetimes) isa FullNetworkModel
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
