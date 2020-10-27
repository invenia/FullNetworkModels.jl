using ElectricityMarkets
using FullNetworkDataPrep.TestUtils: fake_3bus_system
using GLPK
using InHouseFNM
using JuMP
using PowerSystems
using Test

@testset "InHouseFNM.jl" begin
    include("api.jl")
    include("variables.jl")
end
