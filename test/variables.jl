function tests_thermal_variable(fnm, label)
    set_names!(fnm)
    @testset "Variables named `$label` were created with the correct indices" begin
        @test has_variable(fnm.model, label)
        @test issetequal(
            fnm.model[Symbol(label)].axes[1],
            keys(get_generators(fnm.system))
        )
        @test issetequal(fnm.model[Symbol(label)].axes[2], fnm.datetimes)
    end
    return nothing
end

function tests_ancillary_variable(fnm, label)
    @testset "Variables named `$label` were created with the correct indices" begin
        @test has_variable(fnm.model, label)
        @test issubset(
            first.(eachindex(fnm.model[Symbol(label)])),
            keys(get_generators(fnm.system))
        )
        @test issubset(last.(eachindex(fnm.model[Symbol(label)])), fnm.datetimes)
    end
    return nothing
end

function tests_commitment(fnm)
    set_names!(fnm)
    tests_thermal_variable(fnm, "u")
    @testset "Created variables are binary" begin
        @test all(is_binary, fnm.model[:u].data)
    end
    return nothing
end

function tests_startup_shutdown(fnm)
    set_names!(fnm)
    tests_thermal_variable(fnm, "v")
    tests_thermal_variable(fnm, "w")
    t1, t2 = fnm.datetimes[1:2]
    @test sprint(show, constraint_by_name(
        fnm.model, "startup_shutdown_definition[7,$t2]"
    )) == "startup_shutdown_definition[7,$t2] : -u[7,$t1] + u[7,$t2] - v[7,$t2] + w[7,$t2] = 0.0"
    @test !has_constraint(fnm.model, "startup_shutdown_definition[7,$t1]")
    @test sprint(show, constraint_by_name(
        fnm.model, "startup_shutdown_definition_initial[7]"
    )) == "startup_shutdown_definition_initial[7] : u[7,$t1] - v[7,$t1] + w[7,$t1] = 1.0"
    return nothing
end

function tests_bid_variables(fnm, label, f)
    set_names!(fnm)
    @testset "Variables named `$label` were created with the correct indices" begin
        @test has_variable(fnm.model, label)
        @test issetequal(
            fnm.model[Symbol(label)].axes[1], axiskeys(f(fnm.system), 1)
        )
        @test issetequal(fnm.model[Symbol(label)].axes[2], fnm.datetimes)
    end
    return nothing
end

@testset "Variables" begin
    G = Grid
    fnm = FullNetworkModel{UC}(TEST_SYSTEM)
    @testset "var_thermal_generation!" begin
        var_thermal_generation!(G, fnm)
        tests_thermal_variable(fnm, "p")
        @test !has_variable(fnm.model, "u")
    end
    @testset "var_commitment!" begin
        var_commitment!(G, fnm)
        tests_commitment(fnm)
    end
    @testset "var_startup_shutdown!" begin
        var_startup_shutdown!(G, fnm)
        set_names!(fnm; force=true)  # added new variables which need names
        tests_startup_shutdown(fnm)
    end
    @testset "var_ancillary_services!" begin
        var_ancillary_services!(G, fnm)
        tests_thermal_variable(fnm, "u_reg")
        @testset for service in ("r_reg", "r_spin", "r_on_sup", "r_off_sup")
            tests_ancillary_variable(fnm, service)
        end
    end
    @testset "var_bids!" begin
        var_bids!(G, fnm)
        tests_bid_variables(fnm, "inc", get_increments)
        tests_bid_variables(fnm, "dec", get_decrements)
        tests_bid_variables(fnm, "psl", get_price_sensitive_loads)
    end
end
