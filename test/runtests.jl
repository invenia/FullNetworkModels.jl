using Dates
using ElectricityMarkets
using FullNetworkDataPrep: DA, RT, ptdf
using FullNetworkDataPrep.TestUtils: fake_3bus_system
using GLPK
using FullNetworkModels
using MathOptInterface: TerminationStatusCode
using JuMP
using JuMP.Containers: DenseAxisArray
using PowerSystems
using PowerSystemsExtras
using Test
using TimeSeries

const FNM = FullNetworkModels
const TEST_SYSTEM, TEST_PSSE = fake_3bus_system(MISO, DA)
const TEST_SYSTEM_RT, _ = fake_3bus_system(MISO, DA; commitment_forecasts=true)
const TEST_PTDF = ptdf(TEST_PSSE)

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
