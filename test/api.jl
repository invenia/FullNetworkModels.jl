@testset "API functions" begin
    system = fake_3bus_system(MISO)
    fnm = FullNetworkModel(system, GLPK.Optimizer)
    @test sprint(show, fnm) == "FullNetworkModel\nModel formulation: 0 variables\nSystem: 23 components, 24 time periods\n"
end
