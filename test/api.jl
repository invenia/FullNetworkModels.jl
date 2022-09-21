@testset "API functions" begin

    @testset "Prints" begin
        G = FakeGrid
        fnm = FullNetworkModel{UC}(TEST_SYSTEM)
        t1 = DateTime(2017, 12, 15)
        t2 = DateTime(2017, 12, 15, 23)
        @test sprint(show, fnm; context=:compact => true) == "FullNetworkModel{UnitCommitment}($t1 … $t2)"
        @test sprint(show, fnm) == strip("""
            FullNetworkModel{UnitCommitment}
            Time periods: $t1 to $t2
            System: 9 components
            Model formulation: 0 variables and 0 constraints
            """
        )
        var_commitment!(G, fnm)
        n_units = length(fnm.datetimes) * length(get_generators(fnm.system))
        @test sprint(show, fnm) == strip("""
            FullNetworkModel{UnitCommitment}
            Time periods: $t1 to $t2
            System: 9 components
            Model formulation: $n_units variables and $n_units constraints
              Variable names: u
            """
        )
        con_must_run!(G, fnm)
        @test sprint(show, fnm) == strip("""
            FullNetworkModel{UnitCommitment}
            Time periods: $t1 to $t2
            System: 9 components
            Model formulation: $n_units variables and $(2 * n_units) constraints
              Variable names: u
              Constraint names: must_run
            """
        )

        for T in (UC, ED, Slacks)
            x = T()
            # `repr` prints valid code for reconstructing the object
            @test eval(Meta.parse(repr(x))) == x
            # defaut `show` in the REPL uses prettier printing including line breaks
            @test startswith(sprint(show, MIME("text/plain"), x), "$T:\n  ")
        end
    end

    @testset "API extensions" begin
        fnm = FullNetworkModel{UC}(TEST_SYSTEM)
        # test model has no solver
        @test solver_name(fnm.model) === solver_name(Model())

        set_optimizer(fnm, HiGHS.Optimizer)
        @test solver_name(fnm.model) == "HiGHS"

        set_optimizer_attribute(fnm, "primal_feasibility_tolerance", 1e-2)
        @test get_optimizer_attribute(fnm, "primal_feasibility_tolerance") == 1e-2

        set_optimizer_attributes(fnm, "primal_feasibility_tolerance" => 1e-3, "simplex_iteration_limit" => 10_000)
        @test get_optimizer_attribute(fnm, "primal_feasibility_tolerance") == 1e-3
        @test get_optimizer_attribute(fnm, "simplex_iteration_limit") == 10_000

        set_silent(fnm.model)
        optimize!(fnm)
        @test solve_time(fnm.model) > 0
    end
end
