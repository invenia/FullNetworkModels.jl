function _convert_jump_number(x)
    return mod(x, 1) == 0 ? convert(Int, x) : x
end

function tests_thermal_variable_cost(fnm)
    @testset "Variables and constraints were created with correct names and indices" begin
        @test has_variable(fnm.model, "p_aux")
        @test has_constraint(fnm.model, "gen_block_limits")
        unit_codes = get_unit_codes(ThermalGen, fnm.system)
        n_periods = get_forecasts_horizon(fnm.system)
        @test issetequal(fnm.model[:generation_definition].axes[1], unit_codes)
        @test issetequal(fnm.model[:generation_definition].axes[2], 1:n_periods)
        @testset for g in unit_codes, t in 1:n_periods, b in 1:3
            @test (g, t, b) in keys(fnm.model[:gen_block_limits].data)
        end
    end
    return nothing
end

function tests_thermal_linear_cost(fnm, var, f)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    cost = f(fnm.system)
    str = string(objective_function(fnm.model))
    @testset "Cost was correctly added to objective" begin
        @testset for g in unit_codes, t in 1:n_periods
            C = mod(cost[g][t], 1) == 0 ? convert(Int, cost[g][t]) : cost[g][t]
            @test occursin("+ $C $var[$g,$t]", str)
        end
    end
end

tests_thermal_noload_cost(fnm) = tests_thermal_linear_cost(fnm, :u, get_noload_cost)
tests_thermal_startup_cost(fnm) = tests_thermal_linear_cost(fnm, :v, get_startup_cost)

function tests_ancillary_costs(fnm)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    cost_reg = get_regulation_cost(fnm.system)
    cost_spin = get_spinning_cost(fnm.system)
    cost_on_sup = get_on_sup_cost(fnm.system)
    cost_off_sup = get_off_sup_cost(fnm.system)
    str = string(objective_function(fnm.model))
    @testset "All ancillary terms correctly added to objective" begin
        @testset for g in unit_codes, t in 1:n_periods
            C_reg = _convert_jump_number(cost_reg[g][t])
            C_spin = _convert_jump_number(cost_spin[g][t])
            C_on_sup = _convert_jump_number(cost_on_sup[g][t])
            C_off_sup = _convert_jump_number(cost_off_sup[g][t])
            @test occursin("$C_reg r_reg[$g,$t]", str)
            @test occursin("$C_spin r_spin[$g,$t]", str)
            @test occursin("$C_on_sup r_on_sup[$g,$t]", str)
            @test occursin("$C_off_sup r_off_sup[$g,$t]", str)
        end
    end
    return nothing
end

@testset "Objectives" begin
    @testset "thermal_variable_cost!" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        @test objective_function(fnm.model) == AffExpr()
        @testset "Adding cost before thermal generation throws error" begin
            @test_throws AssertionError thermal_variable_cost!(fnm)
        end
        @testset "Economic dispatch (just thermal generation added)" begin
            add_thermal_generation!(fnm)
            thermal_variable_cost!(fnm)
            tests_thermal_variable_cost(fnm)
            @test sprint(show, constraint_by_name(fnm.model, "gen_block_limits[7,1,1]")) ==
                "gen_block_limits[7,1,1] : p_aux[7,1,1] ≤ 0.5"
        end
        @testset "unit commitment (both thermal generation and commitment added)" begin
            fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
            add_thermal_generation!(fnm)
            add_commitment!(fnm)
            thermal_variable_cost!(fnm)
            tests_thermal_variable_cost(fnm)
            @test sprint(show, constraint_by_name(fnm.model, "gen_block_limits[7,1,1]")) ==
                "gen_block_limits[7,1,1] : -0.5 u[7,1] + p_aux[7,1,1] ≤ 0.0"
        end
    end
    @testset "ancillary_service_costs!" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_commitment!(fnm)
        add_ancillary_services!(fnm)
        ancillary_service_costs!(fnm)
        tests_ancillary_costs(fnm)
    end
    @testset "thermal_noload_cost!" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_thermal_generation!(fnm)
        add_commitment!(fnm)
        thermal_variable_cost!(fnm)
        thermal_noload_cost!(fnm)
        tests_thermal_noload_cost(fnm)
    end
    @testset "thermal_startup_cost!" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_commitment!(fnm)
        add_startup_shutdown!(fnm)
        thermal_noload_cost!(fnm)
        thermal_startup_cost!(fnm)
        tests_thermal_startup_cost(fnm)
    end
end
