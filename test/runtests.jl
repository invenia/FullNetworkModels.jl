using Dates
using ElectricityMarkets
using FullNetworkDataPrep.TestUtils: fake_3bus_system
using FullNetworkDataPrep: DA, RT
using FullNetworkModels
using FullNetworkModels: _expand_slacks
using HiGHS
using JuMP.Containers: DenseAxisArray
using JuMP
using MathOptInterface: TerminationStatusCode
using Memento.TestUtils: @test_log
using PowerSystems
using PowerSystemsExtras
using PowerSystemsExtras: PTDF
using Test
using TimeSeries

const FNM = FullNetworkModels
const TEST_SYSTEM = fake_3bus_system(MISO, DA)
const TEST_SYSTEM_RT = fake_3bus_system(MISO, DA; commitment_forecasts=true)
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
