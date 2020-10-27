using ElectricityMarkets
using FullNetworkDataPrep.TestUtils: fake_3bus_system
using GLPK
using InHouseFNM
using JuMP
using PowerSystems
using Test

const TEST_SYSTEM = fake_3bus_system(MISO)

@testset "InHouseFNM.jl" begin
    include("api.jl")
    include("variables.jl")
    include("templates.jl")
end
