function _convert_jump_number(x)
    return mod(x, 1) == 0 ? convert(Int, x) : x
end

function tests_thermal_variable_cost(fnm)
    @testset "Variables and constraints were created with correct names and indices" begin
        @test has_variable(fnm.model, "p_aux")
        @test has_constraint(fnm.model, "gen_block_limits")
        unit_codes = get_unit_codes(ThermalGen, fnm.system)
        @test issetequal(fnm.model[:generation_definition].axes[1], unit_codes)
        @test issetequal(fnm.model[:generation_definition].axes[2], fnm.datetimes)
        @testset for g in unit_codes, t in fnm.datetimes, b in 1:3
            @test (g, t, b) in keys(fnm.model[:gen_block_limits].data)
        end
    end
    return nothing
end

function tests_thermal_linear_cost(fnm, var, f)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    cost = f(fnm.system)
    str = string(objective_function(fnm.model))
    @testset "Cost was correctly added to objective" begin
        @testset for g in unit_codes, t in fnm.datetimes
            C = mod(cost[g, t], 1) == 0 ? convert(Int, cost[g, t]) : cost[g, t]
            @test occursin("+ $C $var[$g,$t]", str)
        end
    end
end

tests_thermal_noload_cost(fnm) = tests_thermal_linear_cost(fnm, :u, get_noload_cost)
tests_thermal_startup_cost(fnm) = tests_thermal_linear_cost(fnm, :v, get_startup_cost)

function tests_ancillary_costs(fnm)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    cost_reg = get_regulation_cost(fnm.system)
    cost_spin = get_spinning_cost(fnm.system)
    cost_on_sup = get_on_sup_cost(fnm.system)
    cost_off_sup = get_off_sup_cost(fnm.system)
    str = string(objective_function(fnm.model))
    @testset "All ancillary terms correctly added to objective" begin
        for g in unit_codes, t in fnm.datetimes
            C_reg = _convert_jump_number(cost_reg[g, t])
            C_spin = _convert_jump_number(cost_spin[g, t])
            C_on_sup = _convert_jump_number(cost_on_sup[g, t])
            C_off_sup = _convert_jump_number(cost_off_sup[g, t])
            @test occursin("$C_reg r_reg[$g,$t]", str)
            @test occursin("$C_spin r_spin[$g,$t]", str)
            @test occursin("$C_on_sup r_on_sup[$g,$t]", str)
            @test occursin("$C_off_sup r_off_sup[$g,$t]", str)
        end
    end
    return nothing
end

@testset "Objectives" begin
    @testset "obj_thermal_variable_cost!" begin
        t = first(get_forecast_timestamps(TEST_SYSTEM))
        @testset "Adding cost before generation variables throws error" begin
            fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
            @test objective_function(fnm.model) == AffExpr()
            @test_throws Exception obj_thermal_variable_cost!(fnm)
        end
        @testset "Economic dispatch (just thermal generation added)" begin
            fnm = FullNetworkModel{ED}(TEST_SYSTEM_RT, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            obj_thermal_variable_cost!(fnm)
            tests_thermal_variable_cost(fnm)
            @test sprint(show, constraint_by_name(fnm.model, "gen_block_limits[7,$t,1]")) ==
                "gen_block_limits[7,$t,1] : p_aux[7,$t,1] ≤ 0.0"
            @test sprint(show, constraint_by_name(fnm.model, "gen_block_limits[3,$t,1]")) ==
                "gen_block_limits[3,$t,1] : p_aux[3,$t,1] ≤ 0.5"
        end
        @testset "unit commitment (both thermal generation and commitment added)" begin
            fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            obj_thermal_variable_cost!(fnm)
            tests_thermal_variable_cost(fnm)
            @test sprint(show, constraint_by_name(fnm.model, "gen_block_limits[7,$t,1]")) ==
                "gen_block_limits[7,$t,1] : -0.5 u[7,$t] + p_aux[7,$t,1] ≤ 0.0"
        end
    end
    @testset "obj_ancillary_costs! $T" for T in (UC, ED)
        fnm = FullNetworkModel{T}(TEST_SYSTEM, GLPK.Optimizer)
        var_commitment!(fnm)
        var_ancillary_services!(fnm)
        obj_ancillary_costs!(fnm)
        tests_ancillary_costs(fnm)
    end
    @testset "obj_thermal_noload_cost!" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
        var_thermal_generation!(fnm)
        var_commitment!(fnm)
        obj_thermal_variable_cost!(fnm)
        obj_thermal_noload_cost!(fnm)
        tests_thermal_noload_cost(fnm)
    end
    @testset "obj_thermal_startup_cost!" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
        var_commitment!(fnm)
        var_startup_shutdown!(fnm)
        obj_thermal_noload_cost!(fnm)
        obj_thermal_startup_cost!(fnm)
        tests_thermal_startup_cost(fnm)
    end
    @testset "obj_bids!" begin
        system = fake_3bus_system(MISO, DA; n_periods=2)
        fnm = FullNetworkModel{UC}(system, GLPK.Optimizer)
        var_bids!(fnm)
        obj_bids!(fnm)
        # Check if objective function accurately reflects the bids in the system
        # All bids have just one block equal to $100/pu
        # https://gitlab.invenia.ca/invenia/research/FullNetworkDataPrep.jl/-/blob/16f570e9116d86a2ce65e2e08aa702cefa268cc5/src/testutils.jl#L162
        inc_name, dec_name, psd_name = ("111_1", "222_1", "333_1")
        inc_aux, dec_aux, psd_aux = fnm.model[:inc_aux], fnm.model[:dec_aux], fnm.model[:psd_aux]
        t1, t2 = fnm.datetimes[1:2]
        @test objective_function(fnm.model) == 100 * (
            inc_aux[inc_name, t1, 1] + inc_aux[inc_name, t2, 1]
            - dec_aux[dec_name, t1, 1] - dec_aux[dec_name, t2, 1]
            - psd_aux[psd_name, t1, 1] - psd_aux[psd_name, t2, 1]
        )
    end
end
