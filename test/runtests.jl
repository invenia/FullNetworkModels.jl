using Dates
using ElectricityMarkets
using FullNetworkDataPrep: DA, RT
using FullNetworkDataPrep.TestUtils: fake_3bus_system
using GLPK
using FullNetworkModels
using MathOptInterface: TerminationStatusCode
using JuMP
using PowerSystems
using PowerSystemsExtras
using Random
using Test
using TimeSeries

const FNM = FullNetworkModels
const TEST_SYSTEM = fake_3bus_system(MISO, DA)
const TEST_SYSTEM_RT = fake_3bus_system(MISO, DA; commitment_forecasts=true)

@testset "FullNetworkModels.jl" begin
    include("api.jl")
    include("constraints.jl")
    include("feasibility_checks.jl")
    include("internal.jl")
    include("objectives.jl")
    include("variables.jl")
    include("templates.jl")
    include("write.jl")
end
