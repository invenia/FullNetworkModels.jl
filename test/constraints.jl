function tests_generation_limits(fnm)
    @testset "Test if constraints were created with the correct indices" begin
        @test has_constraint(fnm.model, "generation_min")
        @test has_constraint(fnm.model, "generation_max")
        @test issetequal(fnm.model[:generation_min].axes[1], (7, 3))
        @test issetequal(fnm.model[:generation_min].axes[2], fnm.datetimes)
        @test issetequal(fnm.model[:generation_max].axes[1], (7, 3))
        @test issetequal(fnm.model[:generation_max].axes[2], fnm.datetimes)
    end
    return nothing
end

function tests_ancillary_limits(fnm::FullNetworkModel{<:UC})
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_max[7,$t]")) ==
        "ancillary_max[7,$t] : p[7,$t] - 8 u[7,$t] + r_reg[7,$t] + r_spin[7,$t] + r_on_sup[7,$t] + 0.5 u_reg[7,$t] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_min[7,$t]")) ==
        "ancillary_min[7,$t] : p[7,$t] - 0.5 u[7,$t] - r_reg[7,$t] ≥ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_max[7,$t]")) ==
        "regulation_max[7,$t] : r_reg[7,$t] - 3.5 u_reg[7,$t] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "spin_and_sup_max[7,$t]")) ==
        "spin_and_sup_max[7,$t] : -7.5 u[7,$t] + r_spin[7,$t] + r_on_sup[7,$t] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "off_sup_max[7,$t]")) ==
        "off_sup_max[7,$t] : 7.5 u[7,$t] + r_off_sup[7,$t] ≤ 7.5"
    # Units in test system provide regulation, spinning, and on/off supplemental
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    for str in ("reg", "u_reg", "spin", "on_sup", "off_sup"), g in unit_codes, t in fnm.datetimes
        @test constraint_by_name(fnm.model, "zero_$str[$g,$t]") === nothing
    end
    return nothing
end

# The output of these `sprint`s change depending on the value of U; we assume it's always 1
# since that's how we're defining the test system.
function tests_ancillary_limits(fnm::FullNetworkModel{<:ED})
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_max[7,$t]")) ==
        "ancillary_max[7,$t] : p[7,$t] + r_reg[7,$t] + r_spin[7,$t] + r_on_sup[7,$t] ≤ 7.5"
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_min[7,$t]")) ==
        "ancillary_min[7,$t] : p[7,$t] - r_reg[7,$t] ≥ 0.5"
    @test sprint(show, constraint_by_name(fnm.model, "spin_and_sup_max[7,$t]")) ==
        "spin_and_sup_max[7,$t] : r_spin[7,$t] + r_on_sup[7,$t] ≤ 7.5"
    @test sprint(show, constraint_by_name(fnm.model, "off_sup_max[7,$t]")) ==
        "off_sup_max[7,$t] : r_off_sup[7,$t] ≤ 0.0"
    # Units in test system provide regulation, spinning, and on/off supplemental
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    for str in ("reg", "spin", "on_sup", "off_sup"), g in unit_codes, t in fnm.datetimes
        @test constraint_by_name(fnm.model, "zero_$str[$g,$t]") === nothing
    end
    return nothing
end

function tests_regulation_requirements(fnm::FullNetworkModel{<:UC})
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[1,$t]")) ==
        "regulation_requirements[1,$t] : r_reg[3,$t] ≥ 0.3"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[2,$t]")) ==
        "regulation_requirements[2,$t] : r_reg[7,$t] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),$t]"
    )) == "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),$t] : r_reg[7,$t] + r_reg[3,$t] ≥ 0.8"
    return nothing
end

function tests_regulation_requirements(fnm::FullNetworkModel{<:ED})
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[1,$t]")) ==
        "regulation_requirements[1,$t] : r_reg[3,$t] + Γ_reg_req[1,$t] ≥ 0.3"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[2,$t]")) ==
        "regulation_requirements[2,$t] : r_reg[7,$t] + Γ_reg_req[2,$t] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),$t]"
    )) == "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),$t] : r_reg[7,$t] + r_reg[3,$t] + Γ_reg_req[$(FNM.MARKET_WIDE_ZONE),$t] ≥ 0.8"
    return nothing
end

function tests_operating_reserve_requirements(fnm::FullNetworkModel{<:UC})
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,$t]"
    )) == "operating_reserve_requirements[1,$t] : r_reg[3,$t] + r_spin[3,$t] + r_on_sup[3,$t] + r_off_sup[3,$t] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,$t]"
    )) == "operating_reserve_requirements[2,$t] : r_reg[7,$t] + r_spin[7,$t] + r_on_sup[7,$t] + r_off_sup[7,$t] ≥ 0.5"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),$t]"
    )) == "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),$t] : r_reg[7,$t] + r_reg[3,$t] + r_spin[7,$t] + r_spin[3,$t] + r_on_sup[7,$t] + r_on_sup[3,$t] + r_off_sup[7,$t] + r_off_sup[3,$t] ≥ 1.2"
    return nothing
end

function tests_operating_reserve_requirements(fnm::FullNetworkModel{<:ED})
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,$t]"
    )) == "operating_reserve_requirements[1,$t] : r_reg[3,$t] + r_spin[3,$t] + r_on_sup[3,$t] + r_off_sup[3,$t] + Γ_or_req[1,$t] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,$t]"
    )) == "operating_reserve_requirements[2,$t] : r_reg[7,$t] + r_spin[7,$t] + r_on_sup[7,$t] + r_off_sup[7,$t] + Γ_or_req[2,$t] ≥ 0.5"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),$t]"
    )) == "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),$t] : r_reg[7,$t] + r_reg[3,$t] + r_spin[7,$t] + r_spin[3,$t] + r_on_sup[7,$t] + r_on_sup[3,$t] + r_off_sup[7,$t] + r_off_sup[3,$t] + Γ_or_req[$(FNM.MARKET_WIDE_ZONE),$t] ≥ 1.2"
    return nothing
end

function tests_ramp_rates(fnm; slack=nothing)
    t1, t2 = fnm.datetimes[1:2]
    @test sprint(show, constraint_by_name(
        fnm.model, "ramp_regulation[3,$t1]"
    )) == "ramp_regulation[3,$t1] : r_reg[3,$t1] ≤ 1.25"
    @test sprint(show, constraint_by_name(
        fnm.model, "ramp_spin_sup[3,$t1]"
    )) == "ramp_spin_sup[3,$t1] : r_spin[3,$t1] + r_on_sup[3,$t1] + r_off_sup[3,$t1] ≤ 2.5"
    @test constraint_by_name(fnm.model, "ramp_up[3,$t1]") === nothing
    @test constraint_by_name(fnm.model, "ramp_down[3,$t1]") === nothing
    if slack !== nothing
        @test sprint(show, constraint_by_name(
        fnm.model, "ramp_up[3,$t2]"
        )) == "ramp_up[3,$t2] : -p[3,$t1] + p[3,$t2] - 15 u[3,$t1] - 0.5 v[3,$t2] - Γ_ramp[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down[3,$t2]"
        )) == "ramp_down[3,$t2] : p[3,$t1] - p[3,$t2] - 15 u[3,$t2] - 0.5 w[3,$t2] - Γ_ramp[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_up_initial[3]"
        )) == "ramp_up_initial[3] : p[3,$t1] - 0.5 v[3,$t1] - Γ_ramp[3,$t1] ≤ 16.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down_initial[3]"
        )) == "ramp_down_initial[3] : -p[3,$t1] - 15 u[3,$t1] - 0.5 w[3,$t1] - Γ_ramp[3,$t1] ≤ -1.0"
    else
        @test sprint(show, constraint_by_name(
        fnm.model, "ramp_up[3,$t2]"
        )) == "ramp_up[3,$t2] : -p[3,$t1] + p[3,$t2] - 15 u[3,$t1] - 0.5 v[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down[3,$t2]"
        )) == "ramp_down[3,$t2] : p[3,$t1] - p[3,$t2] - 15 u[3,$t2] - 0.5 w[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_up_initial[3]"
        )) == "ramp_up_initial[3] : p[3,$t1] - 0.5 v[3,$t1] ≤ 16.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down_initial[3]"
        )) == "ramp_down_initial[3] : -p[3,$t1] - 15 u[3,$t1] - 0.5 w[3,$t1] ≤ -1.0"
    end
    return nothing
end

function tests_energy_balance(fnm::FullNetworkModel{<:ED})
    load_names = get_load_names(PowerLoad, fnm.system)
    D = get_fixed_loads(fnm.system)
    @testset "Constraints were correctly defined" for t in fnm.datetimes
        system_load = sum(D[f, t] for f in load_names)
        @test sprint(show, constraint_by_name(fnm.model, "energy_balance[$t]")) ==
            "energy_balance[$t] : p[7,$t] + p[3,$t] = $(system_load)"
    end
    return nothing
end
function tests_energy_balance(fnm::FullNetworkModel{<:UC})
    load_names = get_load_names(PowerLoad, fnm.system)
    D = get_fixed_loads(fnm.system)
    @testset "Constraints were correctly defined" for t in fnm.datetimes
        system_load = sum(D[f, t] for f in load_names)
        @test sprint(show, constraint_by_name(fnm.model, "energy_balance[$t]")) ==
            "energy_balance[$t] : p[7,$t] + p[3,$t] + inc[111_1,$t] - dec[222_1,$t] - psd[333_1,$t] = $(system_load)"
    end
    return nothing
end

function tests_branch_flow_limits(T, fnm::FullNetworkModel, sys_ptdf)
    @testset "All branch constraints were added" begin
        @test has_constraint(fnm.model, "nodal_net_injection")
        @test has_constraint(fnm.model, "branch_flows")
        @test has_constraint(fnm.model, "branch_flow_max")
        @test has_constraint(fnm.model, "branch_flow_min")
        @test has_constraint(fnm.model, "branch_flow_sl1_zero")
        @test has_constraint(fnm.model, "branch_flow_sl2_zero")
        @test has_constraint(fnm.model, "branch_flow_sl1_one")
        @test has_constraint(fnm.model, "branch_flow_sl2_one")
        @test has_constraint(fnm.model, "branch_flow_sl1_two")
        @test has_constraint(fnm.model, "branch_flow_sl2_two")
    end
    system = fnm.system
    mon_branches_names = get_monitored_branch_names(Branch, system)
    bus_numbers = get_bus_numbers(system)
    load_names_perbus = get_load_names_perbus(PowerLoad, system)
    D = get_fixed_loads(system)
    pg = Array{String}(undef, 3)
    if T == UC
        inc_names_perbus = get_bid_names_perbus(Increment, system)
        dec_names_perbus = get_bid_names_perbus(Decrement, system)
        psd_names_perbus = get_bid_names_perbus(PriceSensitiveDemand, system)
        @testset "Nodal net injection" for t in fnm.datetimes
            d_net = 0.0
            pg[1] = " -p[3,$t]"
            pg[2] = " -p[7,$t] +"
            pg[3] = ""
            for n in bus_numbers
                if n !== 1
                    d_net = -sum(D[f, t] for f in load_names_perbus[n])
                    inc_aux = ""
                    dec_aux = ""
                    psd_aux = ""
                else
                    inc_names_aux = inc_names_perbus[n][1]
                    dec_names_aux = dec_names_perbus[n][1]
                    psd_names_aux = psd_names_perbus[n][1]
                    inc_aux = " - inc[$inc_names_aux,$t] +"
                    dec_aux = " dec[$dec_names_aux,$t] +"
                    psd_aux = " psd[$psd_names_aux,$t] +"
                end
                pg_aux = pg[n]
                @test sprint(show, constraint_by_name(fnm.model, "nodal_net_injection[$n,$t]")) ==
                "nodal_net_injection[$n,$t] :$pg_aux$inc_aux$dec_aux$psd_aux p_net[$n,$t] = $d_net"
            end
        end
    else #ED
        @testset "Nodal net injection" for t in fnm.datetimes
            d_net = 0.0
            pg[1] = " -p[3,$t] +"
            pg[2] = " -p[7,$t] +"
            pg[3] = ""
            for n in bus_numbers
                if n !== 1
                    d_net = -sum(D[f, t] for f in load_names_perbus[n])
                end
                pg_aux = pg[n]
                @test sprint(show, constraint_by_name(fnm.model, "nodal_net_injection[$n,$t]")) ==
                "nodal_net_injection[$n,$t] :$pg_aux p_net[$n,$t] = $d_net"
            end
        end
    end
    @testset "Branch flows" for t in fnm.datetimes
        for m in mon_branches_names
            ptdf_aux2 = -sys_ptdf[m,2]
            ptdf_aux3 = -sys_ptdf[m,3]
            @test sprint(show, constraint_by_name(fnm.model, "branch_flows[$m,$t]")) ==
            "branch_flows[$m,$t] : $ptdf_aux2 p_net[2,$t] + $ptdf_aux3 p_net[3,$t] + fl0[$m,$t] = 0.0"
        end
    end
    mon_branches_rates = get_branch_rates(mon_branches_names, system)
    @testset "Thermal Branch Limits" for t in fnm.datetimes
        for m in mon_branches_names
            rate = mon_branches_rates[m]
            @test sprint(show, constraint_by_name(fnm.model, "branch_flow_max[$m,$t]")) ==
            "branch_flow_max[$m,$t] : fl0[$m,$t] - sl1_fl0[$m,$t] - sl2_fl0[$m,$t] ≤ $rate"
            @test sprint(show, constraint_by_name(fnm.model, "branch_flow_min[$m,$t]")) ==
            "branch_flow_min[$m,$t] : fl0[$m,$t] + sl1_fl0[$m,$t] + sl2_fl0[$m,$t] ≥ -$rate"
        end
        @test constraint_by_name(fnm.model, "branch_flow_max[\"Line2\",$t]") === nothing
        @test constraint_by_name(fnm.model, "branch_flow_min[\"Line2\",$t]") === nothing
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
            tests_ancillary_limits(fnm)
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
            tests_ancillary_limits(fnm)
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
        con_generation_ramp_rates!(fnm)
        con_ancillary_ramp_rates!(fnm)
        tests_ramp_rates(fnm)

        @testset "soft constraints" begin
            fnm = FullNetworkModel{T}(TEST_SYSTEM, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            var_startup_shutdown!(fnm)
            var_ancillary_services!(fnm)
            con_generation_ramp_rates!(fnm; slack=1e4)
            con_ancillary_ramp_rates!(fnm)
            tests_ramp_rates(fnm; slack=1e4)
        end
    end
    @testset "Energy balance constraints $T" for (T, t_system) in
        ((UC, TEST_SYSTEM), (ED, TEST_SYSTEM_RT))
        @testset "con_energy_balance!" begin
            fnm = FullNetworkModel{T}(t_system, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            T == UC && var_bids!(fnm)
            con_energy_balance!(fnm)
            tests_energy_balance(fnm)
        end
    end

    @testset "Thermal branch constraints $T" for (T, t_system, t_ptdf) in
        ((UC, TEST_SYSTEM, TEST_PTDF), (ED, TEST_SYSTEM_RT, TEST_PTDF))
        @testset "_con_branch_flow_limits!" begin
            fnm = FullNetworkModel{T}(t_system, GLPK.Optimizer)
            var_thermal_generation!(fnm)
            T == UC && var_bids!(fnm)
            con_thermal_branch!(fnm, t_ptdf)
            tests_branch_flow_limits(T, fnm, t_ptdf)
        end
    end
end
