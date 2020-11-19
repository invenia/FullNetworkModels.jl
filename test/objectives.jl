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

function tests_thermal_noload_cost(fnm)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    cost_nl = get_noload_cost(fnm.system)
    str = string(objective_function(fnm.model))
    @testset "No-load cost was correctly added to objective" begin
        @testset for g in unit_codes, t in 1:n_periods
            C_nl = mod(cost_nl[g][t], 1) == 0 ? convert(Int, cost_nl[g][t]) : cost_nl[g][t]
            @test occursin("+ $C_nl u[$g,$t]", str)
        end
    end
end

@testset "Objectives" begin
    @testset "thermal_variable_cost!" begin
        system = fake_3bus_system(MISO, n_periods=4)
        fnm = FullNetworkModel(system, GLPK.Optimizer)
        @test objective_function(fnm.model) == AffExpr(0)
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
            fnm = FullNetworkModel(system, GLPK.Optimizer)
            add_thermal_generation!(fnm)
            add_commitment!(fnm)
            thermal_variable_cost!(fnm)
            tests_thermal_variable_cost(fnm)
            @test sprint(show, constraint_by_name(fnm.model, "gen_block_limits[7,1,1]")) ==
                "gen_block_limits[7,1,1] : -0.5 u[7,1] + p_aux[7,1,1] ≤ 0.0"
        end
    end
    @testset "thermal_noload_cost!" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_thermal_generation!(fnm)
        add_commitment!(fnm)
        thermal_variable_cost!(fnm)
        thermal_noload_cost!(fnm)
        tests_thermal_noload_cost(fnm)
    end
end
