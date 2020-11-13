@testset "Formulation writing" begin
    @testset "_extract_expression" begin
        expr = "``x = 1``\n"
        @test InHouseFNM._extract_expression(expr) == "x = 1"
    end
    @testset "_write_objective" begin
        exprs = ["``a``", "``- 2b``", "c^2"]
        @test InHouseFNM._write_objective(exprs) == "``\\min a - 2b + c^2``"
    end
    @testset "_write_formulation" begin
        @test InHouseFNM._write_formulation(
            objectives=["``a``", "``- 2b``", "c^2"],
            constraints=["``x = 1``"],
            variables=["``x >= 0``", "``y \\in \\{0, 1\\}``"],
        ) == """
        ``\\min a - 2b + c^2``

        subject to:

        ``x = 1``
        ``x >= 0``
        ``y \\in \\{0, 1\\}``
        """
    end
end
