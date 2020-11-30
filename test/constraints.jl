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

function tests_ancillary_limits(fnm)
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_max[7,1]")) ==
        "ancillary_max[7,1] : p[7,1] - 5 u[7,1] + r_reg[7,1] + 0.5 u_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "ancillary_min[7,1]")) ==
        "ancillary_min[7,1] : p[7,1] - 0.5 u[7,1] - r_reg[7,1] - 0.5 u_reg[7,1] ≥ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_max[7,1]")) ==
        "regulation_max[7,1] : r_reg[7,1] - 1.75 u_reg[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "spin_and_sup_max[7,1]")) ==
        "spin_and_sup_max[7,1] : -4.5 u[7,1] + r_spin[7,1] + r_on_sup[7,1] ≤ 0.0"
    @test sprint(show, constraint_by_name(fnm.model, "off_sup_max[7,1]")) ==
        "off_sup_max[7,1] : 4.5 u[7,1] + r_off_sup[7,1] ≤ 4.5"
    return nothing
end

function tests_regulation_requirements(fnm)
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[1,1]")) ==
        "regulation_requirements[1,1] : r_reg[3,1] ≥ 0.05"
    @test sprint(show, constraint_by_name(fnm.model, "regulation_requirements[2,1]")) ==
        "regulation_requirements[2,1] : r_reg[7,1] ≥ 0.1"
    @test sprint(show, constraint_by_name(
        fnm.model, "regulation_requirements[$(InHouseFNM.MARKET_WIDE_ZONE),1]"
    )) == "regulation_requirements[$(InHouseFNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] ≥ 0.16"
    return nothing
end

function tests_operating_reserve_requirements(fnm)
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[1,1]"
    )) == "operating_reserve_requirements[1,1] : r_reg[3,1] + r_spin[3,1] + r_on_sup[3,1] + r_off_sup[3,1] ≥ 0.1"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[2,1]"
    )) == "operating_reserve_requirements[2,1] : r_reg[7,1] + r_spin[7,1] + r_on_sup[7,1] + r_off_sup[7,1] ≥ 0.15"
    @test sprint(show, constraint_by_name(
        fnm.model, "operating_reserve_requirements[$(InHouseFNM.MARKET_WIDE_ZONE),1]"
    )) == "operating_reserve_requirements[$(InHouseFNM.MARKET_WIDE_ZONE),1] : r_reg[7,1] + r_reg[3,1] + r_spin[7,1] + r_spin[3,1] + r_on_sup[7,1] + r_on_sup[3,1] + r_off_sup[7,1] + r_off_sup[3,1] ≥ 0.21"
    return nothing
end

function tests_energy_balance(fnm)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    load_names = get_load_names(PowerLoad, fnm.system)
    n_periods = get_forecasts_horizon(fnm.system)
    D = get_fixed_loads(fnm.system)
    @testset "Constraints were correctly defined" for t in 1:n_periods
        system_load = sum(D[f][t] for f in load_names)
        @test sprint(show, constraint_by_name(fnm.model, "energy_balance[$t]")) ==
            "energy_balance[$t] : p[7,$t] + p[3,$t] = $(system_load)"
    end
    return nothing
end

@testset "Constraints" begin
    @testset "generation_limits!" begin
        # Test if trying to add constraints without having variables throws error
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        @test_throws AssertionError generation_limits!(fnm)
        # Test for economic dispatch (just thermal generation added)
        add_thermal_generation!(fnm)
        generation_limits!(fnm)
        tests_generation_limits(fnm)
        # Test for unit commitment (both thermal generation and commitment added)
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_thermal_generation!(fnm)
        add_commitment!(fnm)
        generation_limits!(fnm)
        tests_generation_limits(fnm)
    end
    @testset "Ancillary service constraints" begin
        fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
        add_thermal_generation!(fnm)
        add_commitment!(fnm)
        add_ancillary_services!(fnm)
        @testset "ancillary_service_limits!" begin
            ancillary_service_limits!(fnm)
            tests_ancillary_limits(fnm)
        end
        @testset "regulation_requirements!" begin
            regulation_requirements!(fnm)
            tests_regulation_requirements(fnm)
        end
        @testset "regulation_requirements!" begin
            operating_reserve_requirements!(fnm)
            tests_operating_reserve_requirements(fnm)
        end
    end
    @testset "Energy balance constraints" begin
        @testset "energy_balance!" begin
            fnm = FullNetworkModel(TEST_SYSTEM, GLPK.Optimizer)
            add_thermal_generation!(fnm)
            energy_balance!(fnm)
            tests_energy_balance(fnm)
        end
    end
end
