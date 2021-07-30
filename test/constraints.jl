function tests_generation_limits(fnm)
    @testset "Test if constraints were created with the correct indices" begin
        @test has_constraint(fnm.model, "generation_min")
        @test has_constraint(fnm.model, "generation_max")
        @test issetequal(fnm.model[:generation_min].axes[1], (7, 3))
        @test issetequal(fnm.model[:generation_min].axes[2], 1:24)
        @test issetequal(fnm.model[:generation_max].axes[1], (7, 3))
        @test issetequal(fnm.model[:generation_max].axes[2], 1:24)
    end
    return nothing
end

function tests_ancillary_limits_commitment(fnm)
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_max[7,1]")) ==
        "ancillary_max[7,1] : p[7,1] - 8 u[7,1] + r_reg[7,1] + 0.5 u_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_min[7,1]")) ==
        "ancillary_min[7,1] : p[7,1] - 0.5 u[7,1] - r_reg[7,1] ≥ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_max[7,1]")) ==
        "regulation_max[7,1] : r_reg[7,1] - 3.5 u_reg[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "spin_and_sup_max[7,1]")) ==
        "spin_and_sup_max[7,1] : -7.5 u[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "off_sup_max[7,1]")) ==
        "off_sup_max[7,1] : 7.5 u[7,1] + r_off_sup[7,1] ≤ 7.5"
    # Units in test system provide regulation, spinning, and on/off supplemental
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecast_horizon(fnm.system)
    for str in ("reg", "u_reg", "spin", "on_sup", "off_sup"), g in unit_codes, t in 1:n_periods
        @test constraint_by_name(fnm.model, "zero_$str[$g,$t]") === nothing
    end
    return nothing
end

function tests_ancillary_limits_dispatch(fnm)
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_max[7,1]")) ==
        "ancillary_max[7,1] : p[7,1] + r_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_min[7,1]")) ==
        "ancillary_min[7,1] : p[7,1] - r_reg[7,1] ≥ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "spin_and_sup_max[7,1]")) ==
        "spin_and_sup_max[7,1] : r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "off_sup_max[7,1]")) ==
        "off_sup_max[7,1] : r_off_sup[7,1] ≤ 7.5"
    # Units in test system provide regulation, spinning, and on/off supplemental
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    n_periods = get_forecast_horizon(fnm.system)
    for str in ("reg", "spin", "on_sup", "off_sup"), g in unit_codes, t in 1:n_periods
        @test constraint_by_name(fnm.model, "zero_$str[$g,$t]") === nothing
    end
    return nothing
end

function tests_regulation_requirements(fnm::FullNetworkModel{<:UC})
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[1,1]")) ==
        "regulation_requirements[1,1] : r_reg[3,1] ≥ 0.3"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[2,1]")) ==
        "regulation_requirements[2,1] : r_reg[7,1] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),1]"
    )) == "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] ≥ 0.8"
    return nothing
end

function tests_regulation_requirements(fnm::FullNetworkModel{<:ED})
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[1,1]")) ==
        "regulation_requirements[1,1] : r_reg[3,1] + s_reg_req[1,1] ≥ 0.3"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[2,1]")) ==
        "regulation_requirements[2,1] : r_reg[7,1] + s_reg_req[2,1] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),1]"
    )) == "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] + s_reg_req[$(FNM.MARKET_WIDE_ZONE),1] ≥ 0.8"
    return nothing
end

function tests_operating_reserve_requirements(fnm::FullNetworkModel{<:UC})
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,1]"
    )) == "operating_reserve_requirements[1,1] : r_reg[3,1] + r_spin[3,1] + r_on_sup[3,1] + r_off_sup[3,1] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,1]"
    )) == "operating_reserve_requirements[2,1] : r_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] + r_off_sup[7,1] ≥ 0.5"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),1]"
    )) == "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] + r_spin[7,1] + r_spin[3,1] + r_on_sup[7,1] + r_on_sup[3,1] + r_off_sup[7,1] + r_off_sup[3,1] ≥ 1.2"
    return nothing
end

function tests_operating_reserve_requirements(fnm::FullNetworkModel{<:ED})
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,1]"
    )) == "operating_reserve_requirements[1,1] : r_reg[3,1] + r_spin[3,1] + r_on_sup[3,1] + r_off_sup[3,1] + s_op_res_req[1,1] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,1]"
    )) == "operating_reserve_requirements[2,1] : r_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] + r_off_sup[7,1] + s_op_res_req[2,1] ≥ 0.5"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),1]"
    )) == "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] + r_spin[7,1] + r_spin[3,1] + r_on_sup[7,1] + r_on_sup[3,1] + r_off_sup[7,1] + r_off_sup[3,1] + s_op_res_req[$(FNM.MARKET_WIDE_ZONE),1] ≥ 1.2"
    return nothing
end

function tests_operating_reserve_requirements(fnm)
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,1]"
    )) == "operating_reserve_requirements[1,1] : r_reg[3,1] + r_spin[3,1] + r_on_sup[3,1] + r_off_sup[3,1] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,1]"
    )) == "operating_reserve_requirements[2,1] : r_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] + r_off_sup[7,1] ≥ 0.5"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),1]"
    )) == "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] + r_spin[7,1] + r_spin[3,1] + r_on_sup[7,1] + r_on_sup[3,1] + r_off_sup[7,1] + r_off_sup[3,1] ≥ 1.2"
    return nothing
end

function tests_ramp_rates(fnm; slack=nothing)
    @test sprint(show, constraint_by_name(
        fnm.model, "ramp_regulation[3,1]"
    )) == "ramp_regulation[3,1] : r_reg[3,1] ≤ 1.25"
    @test sprint(show, constraint_by_name(
        fnm.model, "ramp_spin_sup[3,1]"
    )) == "ramp_spin_sup[3,1] : r_spin[3,1] + r_on_sup[3,1] + r_off_sup[3,1] ≤ 2.5"
    @test constraint_by_name(fnm.model, "ramp_up[3,1]") === nothing
    @test constraint_by_name(fnm.model, "ramp_down[3,1]") === nothing
    if slack !== nothing
        @test sprint(show, constraint_by_name(
        fnm.model, "ramp_up[3,2]"
        )) == "ramp_up[3,2] : -p[3,1] + p[3,2] - 15 u[3,1] - 0.5 v[3,2] - s_ramp[3,2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down[3,2]"
        )) == "ramp_down[3,2] : p[3,1] - p[3,2] - 15 u[3,2] - 0.5 w[3,2] - s_ramp[3,2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_up_initial[3]"
        )) == "ramp_up_initial[3] : p[3,1] - 0.5 v[3,1] - s_ramp[3,1] ≤ 16.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down_initial[3]"
        )) == "ramp_down_initial[3] : -p[3,1] - 15 u[3,1] - 0.5 w[3,1] - s_ramp[3,1] ≤ -1.0"
    else
        @test sprint(show, constraint_by_name(
        fnm.model, "ramp_up[3,2]"
        )) == "ramp_up[3,2] : -p[3,1] + p[3,2] - 15 u[3,1] - 0.5 v[3,2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down[3,2]"
        )) == "ramp_down[3,2] : p[3,1] - p[3,2] - 15 u[3,2] - 0.5 w[3,2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_up_initial[3]"
        )) == "ramp_up_initial[3] : p[3,1] - 0.5 v[3,1] ≤ 16.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down_initial[3]"
        )) == "ramp_down_initial[3] : -p[3,1] - 15 u[3,1] - 0.5 w[3,1] ≤ -1.0"
    end
    return nothing
end

function tests_energy_balance(fnm)
    load_names = get_load_names(PowerLoad, fnm.system)
    n_periods = get_forecast_horizon(fnm.system)
    D = get_fixed_loads(fnm.system)
    @testset "Constraints were correctly defined" for t in 1:n_periods
        system_load = sum(D[f][t] for f in load_names)
        @test sprint(show, constraint_by_name(fnm.model, "energy_balance[$t]")) ==
            "energy_balance[$t] : p[7,$t] + p[3,$t] + inc[111_1,$t] - dec[222_1,$t] - psd[333_1,$t] = $(system_load)"
    end
    return nothing
end

@testset "Constraints" begin
    @testset "con_generation_limits!" begin
        @testset "ED with gen generator status as a parameter" begin
            fnm = FullNetworkModel{ED}(TEST_SYSTEM_RT, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            con_generation_limits!(fnm)
            tests_generation_limits(fnm)
        end
        @testset "UC with both thermal generation and commitment added" begin
            fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            con_generation_limits!(fnm)
            tests_generation_limits(fnm)
        end
    end
    @testset "Ancillary service constraints UC" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM, GLPK.Optimizer)
        var_thermal_generation!(fnm)
        var_commitment!(fnm)
        var_ancillary_services!(fnm)
        @testset "con_ancillary_limits!" begin
            con_ancillary_limits!(fnm)
            tests_ancillary_limits_commitment(fnm)
        end
        @testset "con_regulation_requirements!" begin
            con_regulation_requirements!(fnm)
            tests_regulation_requirements(fnm)
        end
        @testset "con_operating_reserve_requirements!" begin
            con_operating_reserve_requirements!(fnm)
            tests_operating_reserve_requirements(fnm)
        end
    end
    @testset "Ancillary service constraints ED" begin
        fnm = FullNetworkModel{ED}(TEST_SYSTEM_RT, GLPK.Optimizer)
        var_thermal_generation!(fnm)
        var_commitment!(fnm)
        var_ancillary_services!(fnm)
        @testset "con_ancillary_limits!" begin
            con_ancillary_limits!(fnm)
            tests_ancillary_limits_dispatch(fnm)
        end
        @testset "con_regulation_requirements!" begin
            con_regulation_requirements!(fnm)
            tests_regulation_requirements(fnm)
        end
        @testset "con_operating_reserve_requirements!" begin
            con_operating_reserve_requirements!(fnm)
            tests_operating_reserve_requirements(fnm)
        end
    end
    @testset "Ramp constraints $T" for T in (UC, ED)
        # Basic tests for hard constraints
        fnm = FullNetworkModel{T}(TEST_SYSTEM, GLPK.Optimizer)
        var_thermal_generation!(fnm)
        var_commitment!(fnm)
        var_startup_shutdown!(fnm)
        var_ancillary_services!(fnm)
        con_ramp_rates!(fnm)
        tests_ramp_rates(fnm)

        @testset "soft constraints" begin
            fnm = FullNetworkModel{T}(TEST_SYSTEM, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            var_startup_shutdown!(fnm)
            var_ancillary_services!(fnm)
            con_ramp_rates!(fnm; slack=1e4)
            tests_ramp_rates(fnm; slack=1e4)
        end
    end
    @testset "Energy balance constraints $T" for T in (UC, ED)
        @testset "con_energy_balance!" begin
            fnm = FullNetworkModel{T}(TEST_SYSTEM, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            var_bids!(fnm)
            con_energy_balance!(fnm)
            tests_energy_balance(fnm)
        end
    end
end
