function tests_generation_limits(fnm)
    set_names!(fnm)
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
    set_names!(fnm)
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
    set_names!(fnm)
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
    set_names!(fnm)
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
    set_names!(fnm)
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[1,$t]")) ==
        "regulation_requirements[1,$t] : r_reg[3,$t] + sl_reg_req[1,$t] ≥ 0.3"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[2,$t]")) ==
        "regulation_requirements[2,$t] : r_reg[7,$t] + sl_reg_req[2,$t] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),$t]"
    )) == "regulation_requirements[$(FNM.MARKET_WIDE_ZONE),$t] : r_reg[7,$t] + r_reg[3,$t] + sl_reg_req[$(FNM.MARKET_WIDE_ZONE),$t] ≥ 0.8"
    return nothing
end

function tests_operating_reserve_requirements(fnm::FullNetworkModel{<:UC})
    set_names!(fnm)
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
    set_names!(fnm)
    t = first(fnm.datetimes)
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,$t]"
    )) == "operating_reserve_requirements[1,$t] : r_reg[3,$t] + r_spin[3,$t] + r_on_sup[3,$t] + r_off_sup[3,$t] + sl_or_req[1,$t] ≥ 0.4"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,$t]"
    )) == "operating_reserve_requirements[2,$t] : r_reg[7,$t] + r_spin[7,$t] + r_on_sup[7,$t] + r_off_sup[7,$t] + sl_or_req[2,$t] ≥ 0.5"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),$t]"
    )) == "operating_reserve_requirements[$(FNM.MARKET_WIDE_ZONE),$t] : r_reg[7,$t] + r_reg[3,$t] + r_spin[7,$t] + r_spin[3,$t] + r_on_sup[7,$t] + r_on_sup[3,$t] + r_off_sup[7,$t] + r_off_sup[3,$t] + sl_or_req[$(FNM.MARKET_WIDE_ZONE),$t] ≥ 1.2"
    return nothing
end

function tests_ramp_rates(fnm; slack=nothing)
    set_names!(fnm)
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
        )) == "ramp_up[3,$t2] : -p[3,$t1] + p[3,$t2] - 15 u[3,$t1] - 30 v[3,$t2] - sl_ramp[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down[3,$t2]"
        )) == "ramp_down[3,$t2] : p[3,$t1] - p[3,$t2] - 15 u[3,$t2] - 30 w[3,$t2] - sl_ramp[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_up_initial[3]"
        )) == "ramp_up_initial[3] : p[3,$t1] - 30 v[3,$t1] - sl_ramp[3,$t1] ≤ 16.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down_initial[3]"
        )) == "ramp_down_initial[3] : -p[3,$t1] - 15 u[3,$t1] - 30 w[3,$t1] - sl_ramp[3,$t1] ≤ -1.0"
    else
        @test sprint(show, constraint_by_name(
        fnm.model, "ramp_up[3,$t2]"
        )) == "ramp_up[3,$t2] : -p[3,$t1] + p[3,$t2] - 15 u[3,$t1] - 30 v[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down[3,$t2]"
        )) == "ramp_down[3,$t2] : p[3,$t1] - p[3,$t2] - 15 u[3,$t2] - 30 w[3,$t2] ≤ 0.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_up_initial[3]"
        )) == "ramp_up_initial[3] : p[3,$t1] - 30 v[3,$t1] ≤ 16.0"
        @test sprint(show, constraint_by_name(
            fnm.model, "ramp_down_initial[3]"
        )) == "ramp_down_initial[3] : -p[3,$t1] - 15 u[3,$t1] - 30 w[3,$t1] ≤ -1.0"
    end
    return nothing
end

function tests_energy_balance(fnm::FullNetworkModel{<:ED})
    set_names!(fnm)
    load_names = get_load_names(PowerLoad, fnm.system)
    D = get_fixed_loads(fnm.system)
    @testset "Constraints were correctly defined" for t in fnm.datetimes
        system_load = sum(D[f, t] for f in load_names)
        @test sprint(show, constraint_by_name(fnm.model, "energy_balance[$t]")) ==
            "energy_balance[$t] : p[7,$t] + p[3,$t] + sl_eb_gen[$t] - sl_eb_load[$t] = $(system_load)"
    end
    return nothing
end
function tests_energy_balance(fnm::FullNetworkModel{<:UC})
    set_names!(fnm)
    load_names = get_load_names(PowerLoad, fnm.system)
    D = get_fixed_loads(fnm.system)
    @testset "Constraints were correctly defined" for t in fnm.datetimes
        system_load = sum(D[f, t] for f in load_names)
        @test sprint(show, constraint_by_name(fnm.model, "energy_balance[$t]")) ==
            "energy_balance[$t] : p[7,$t] + p[3,$t] + inc[111_Bus1,$t] - dec[222_Bus1,$t] - psd[333_Bus1,$t] = $(system_load)"
    end
    return nothing
end

function tests_branch_flow_limits(T, fnm::FullNetworkModel)
    set_names!(fnm)
    model = fnm.model
    system = fnm.system

    @testset "All branch constraints were added" begin
        @test has_constraint(model, "nodal_net_injection")
        @test has_constraint(model, "branch_flows_base")
        @test has_constraint(model, "branch_flows_conting")
        @test has_constraint(model, "branch_flow_max_base")
        @test has_constraint(model, "branch_flow_min_base")
        @test has_constraint(model, "branch_flow_max_cont")
        @test has_constraint(model, "branch_flow_min_cont")
        @test has_constraint(model, "branch_flow_sl1_zero")
        @test has_constraint(model, "branch_flow_sl2_zero")
        @test has_constraint(model, "branch_flow_sl2_one")
        @test has_constraint(model, "branch_flow_sl1_two_base")
        @test has_constraint(model, "branch_flow_sl1_two_cont")
    end

    @testset "Branch flows constraints" begin
        for t in fnm.datetimes
            m = "Transformer1"
            (c1, c2) = ("conting1", "conting2")
            (ptdf2, ptdf3)  = ("0.12500000000000003", "0.12499999999999997")
            @test sprint(show, constraint_by_name(model, "branch_flows_base[$m,$t]")) ==
            "branch_flows_base[$m,$t] : -$ptdf2 p_net[Bus2,$t] + $ptdf3 p_net[Bus3,$t] + fl[$m,$t,base_case] = 0.0"
            @test sprint(show, constraint_by_name(model, "branch_flows_conting[$m,$t,$c1]")) ==
            "branch_flows_conting[$m,$t,$c1] : -0.5 fl[Line2,$t,base_case] - fl[$m,$t,base_case] + fl[$m,$t,$c1] = 0.0"
            @test sprint(show, constraint_by_name(model, "branch_flows_conting[$m,$t,$c2]")) ==
            "branch_flows_conting[$m,$t,$c2] : -fl[Line3,$t,base_case] - fl[Line2,$t,base_case] - fl[$m,$t,base_case] + fl[$m,$t,$c2] = 0.0"
        end
    end

    mon_branches_names = get_monitored_branch_names(Branch, system)
    mon_branches_rates_a = get_branch_rates(mon_branches_names, system)
    mon_branches_rates_b = get_branch_rates_b(mon_branches_names, system)
    @testset "Thermal Branch Limits" begin
        for t in fnm.datetimes
            for m in mon_branches_names, c in TEST_CONTINGENCIES
                rate = c =="base_case" ? mon_branches_rates_a[m] : mon_branches_rates_b[m]
                if c == "base_case"
                    @test sprint(show, constraint_by_name(model, "branch_flow_max_base[$m,$t,$c]")) ==
                    "branch_flow_max_base[$m,$t,$c] : fl[$m,$t,$c] - sl1_fl[$m,$t,$c] - sl2_fl[$m,$t,$c] ≤ $rate"
                    @test sprint(show, constraint_by_name(model, "branch_flow_min_base[$m,$t,$c]")) ==
                    "branch_flow_min_base[$m,$t,$c] : fl[$m,$t,$c] + sl1_fl[$m,$t,$c] + sl2_fl[$m,$t,$c] ≥ -$rate"
                else
                    @test sprint(show, constraint_by_name(model, "branch_flow_max_cont[$m,$t,$c]")) ==
                    "branch_flow_max_cont[$m,$t,$c] : fl[$m,$t,$c] - sl1_fl[$m,$t,$c] - sl2_fl[$m,$t,$c] ≤ $rate"
                    @test sprint(show, constraint_by_name(model, "branch_flow_min_cont[$m,$t,$c]")) ==
                    "branch_flow_min_cont[$m,$t,$c] : fl[$m,$t,$c] + sl1_fl[$m,$t,$c] + sl2_fl[$m,$t,$c] ≥ -$rate"
                end
            end
            @test constraint_by_name(model, "branch_flow_max_base[\"Line2\",$t,\"base_case\"]") === nothing
            @test constraint_by_name(model, "branch_flow_min_base[\"Line2\",$t,\"base_case\"]") === nothing
            @test constraint_by_name(model, "branch_flow_max_cont[\"Line2\",$t,\"conting1\"]") === nothing
            @test constraint_by_name(model, "branch_flow_min_cont[\"Line2\",$t,\"conting1\"]") === nothing
            @test constraint_by_name(model, "branch_flow_max_cont[\"Line2\",$t,\"conting2\"]") === nothing
            @test constraint_by_name(model, "branch_flow_min_cont[\"Line2\",$t,\"conting2\"]") === nothing
        end
    end
    return nothing
end

# A simple unit commitment with no ancillary services for the sake of tests.
function _simple_template(
    system::System, ::Type{UC}, solver, datetimes=get_forecast_timestamps(system);
    slack=nothing
)
    fnm = FullNetworkModel{UC}(system, datetimes)
    var_thermal_generation!(fnm)
    var_commitment!(fnm)
    var_bids!(fnm)
    con_generation_limits!(fnm)
    con_energy_balance!(fnm; slack)
    con_must_run!(fnm)
    con_availability!(fnm)
    obj_thermal_variable_cost!(fnm)
    obj_thermal_noload_cost!(fnm)
    obj_bids!(fnm)
    set_optimizer(fnm, solver)
    set_silent(fnm.model) # to reduce test verbosity
    set_names!(fnm)
    return fnm
end

# A simple economic dispatch with no ancillary services for the sake of tests.
function _simple_template(
    system::System, ::Type{ED}, solver, datetimes=get_forecast_timestamps(system);
    slack = nothing
)
    fnm = FullNetworkModel{ED}(system, datetimes)
    var_thermal_generation!(fnm)
    con_generation_limits!(fnm)
    con_energy_balance!(fnm; slack)
    obj_thermal_variable_cost!(fnm)
    set_optimizer(fnm, solver)
    set_silent(fnm.model) # to reduce test verbosity
    set_names!(fnm)
    return fnm
end

@testset "Constraints" begin
    @testset "con_generation_limits!" begin
        @testset "ED with gen generator status as a parameter" begin
            fnm = FullNetworkModel{ED}(TEST_SYSTEM_RT)
            var_thermal_generation!(fnm)
            con_generation_limits!(fnm)
            tests_generation_limits(fnm)
        end
        @testset "UC with both thermal generation and commitment added" begin
            fnm = FullNetworkModel{UC}(TEST_SYSTEM)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            con_generation_limits!(fnm)
            tests_generation_limits(fnm)
        end
    end
    @testset "Ancillary service constraints UC" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM)
        var_thermal_generation!(fnm)
        var_commitment!(fnm)
        var_ancillary_services!(fnm)
        @testset "con_ancillary_limits!" begin
            con_ancillary_limits!(fnm)
            tests_ancillary_limits(fnm)
        end
        @testset "con_regulation_requirements!" begin
            con_regulation_requirements!(fnm)
            set_names!(fnm; force=true)  # added new constraints which need names
            tests_regulation_requirements(fnm)
        end
        @testset "con_operating_reserve_requirements!" begin
            con_operating_reserve_requirements!(fnm)
            set_names!(fnm; force=true)  # added new constraints which need names
            tests_operating_reserve_requirements(fnm)
        end
    end
    @testset "Ancillary service constraints ED" begin
        fnm = FullNetworkModel{ED}(TEST_SYSTEM_RT)
        var_thermal_generation!(fnm)
        var_ancillary_services!(fnm)
        @testset "con_ancillary_limits!" begin
            con_ancillary_limits!(fnm)
            tests_ancillary_limits(fnm)
        end
        @testset "con_regulation_requirements!" begin
            con_regulation_requirements!(fnm)
            set_names!(fnm; force=true)  # added new constraints which need names
            tests_regulation_requirements(fnm)
        end
        @testset "con_operating_reserve_requirements!" begin
            con_operating_reserve_requirements!(fnm)
            set_names!(fnm; force=true)  # added new constraints which need names
            tests_operating_reserve_requirements(fnm)
        end
    end
    @testset "Ramp constraints $T" for T in (UC, ED)
        @testset "Hard constraints" begin
            fnm = FullNetworkModel{T}(TEST_SYSTEM)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            var_startup_shutdown!(fnm)
            var_ancillary_services!(fnm)
            con_generation_ramp_rates!(fnm)
            con_ancillary_ramp_rates!(fnm)
            tests_ramp_rates(fnm)
        end

        @testset "Soft constraints" begin
            fnm = FullNetworkModel{T}(TEST_SYSTEM)
            var_thermal_generation!(fnm)
            var_commitment!(fnm)
            var_startup_shutdown!(fnm)
            var_ancillary_services!(fnm)
            con_generation_ramp_rates!(fnm; slack=1e4)
            con_ancillary_ramp_rates!(fnm)
            tests_ramp_rates(fnm; slack=1e4)
        end
    end
    @testset "Energy balance constraints $T" for (T, t_system, slack) in
        ((UC, TEST_SYSTEM, nothing), (ED, TEST_SYSTEM_RT, 1e4))
        @testset "con_energy_balance!" begin
            fnm = FullNetworkModel{T}(t_system)
            var_thermal_generation!(fnm)
            T == UC && var_bids!(fnm)
            con_energy_balance!(fnm, slack=slack)
            tests_energy_balance(fnm)
        end
    end

    @testset "con_must_run!" begin
        # Create a system with a very cheap generator
        system = deepcopy(TEST_SYSTEM)
        gen3 = get_component(ThermalGen, system, "3")
        remove_time_series!(system, SingleTimeSeries, gen3, "offer_curve")
        cheap_offer_curve = [(0.1, 200.0), (0.5, 800.0)]
        datetimes = get_forecast_timestamps(system)
        ta = TimeArray(datetimes, fill(cheap_offer_curve, 24))
        add_time_series!(system, gen3, SingleTimeSeries("offer_curve", ta))

        # Check that the more expensive generator is not committed
        fnm = _simple_template(system, UC, HiGHS.Optimizer)
        optimize!(fnm)
        u = value.(fnm.model[:u])
        @test u[7, :].data == zeros(24)

        # Now replace the must run flag of the more expensive generator with 1's
        gen7 = get_component(ThermalGen, system, "7")
        remove_time_series!(system, SingleTimeSeries, gen7, "must_run")
        ta = TimeArray(datetimes, fill(1, 24))
        add_time_series!(system, gen7, SingleTimeSeries("must_run", ta))

        # Check that generator 7 is now committed throughout the day
        fnm = _simple_template(system, UC, HiGHS.Optimizer)
        optimize!(fnm)
        u = value.(fnm.model[:u])
        @test u[7, :].data == ones(24)
    end

    @testset "con_availability!" begin
        # Edit system so that gen3 is unavailable during the last hour
        system = deepcopy(TEST_SYSTEM)
        gen7 = get_component(ThermalGen, system, "7")
        remove_time_series!(system, SingleTimeSeries, gen7, "availability")
        datetimes = get_forecast_timestamps(system)
        ta = TimeArray(datetimes, vcat(ones(Int, 23), 0))
        add_time_series!(system, gen7, SingleTimeSeries("availability", ta))

        # Check that gen3 was not committed during the last hour
        fnm = _simple_template(system, UC, HiGHS.Optimizer)
        optimize!(fnm)
        u = value.(fnm.model[:u])
        p = value.(fnm.model[:p])
        @test u[7, :].data == vcat(ones(23), 0)
        @test all(p[7, :].data[1:(end - 1)] .> 0.0)
        @test p[7, :].data[end] == 0.0
    end

    @testset "Thermal branch constraints $T" for (T, t_system) in
        ((UC, TEST_SYSTEM), (ED, TEST_SYSTEM_RT))
        @testset "_con_branch_flow_limits!" begin
            fnm = FullNetworkModel{T}(t_system)
            var_thermal_generation!(fnm)
            T == UC && var_bids!(fnm)
            con_thermal_branch!(fnm)
            tests_branch_flow_limits(T, fnm)
        end
    end
end
