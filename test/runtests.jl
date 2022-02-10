using Cbc
using Clp
using Dates
using ElectricityMarkets
using FullNetworkDataPrep: DA, RT
using FullNetworkDataPrep.TestUtils: fake_3bus_system
using FullNetworkModels
using FullNetworkModels: _expand_slacks
using MathOptInterface: TerminationStatusCode
using JuMP
using JuMP.Containers: DenseAxisArray
using PowerSystems
using PowerSystemsExtras
using PowerSystemsExtras: PTDF
using Test
using TimeSeries

const FNM = FullNetworkModels
const TEST_SYSTEM, _ = fake_3bus_system(MISO, DA)
const TEST_SYSTEM_RT, _ = fake_3bus_system(MISO, DA; commitment_forecasts=true)
const TEST_LODF_DICT = get_lodf_dict(TEST_SYSTEM)
const TEST_SCENARIOS = vcat("base_case", keys(TEST_LODF_DICT)...)

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
