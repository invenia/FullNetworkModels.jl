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

# Name individual variables and constraints to allow us testing our expressions using `sprint`
#
# Short-circuit if any names already present, assuming if any var/con has a name then they
# all do; this allows us to call `set_names!` many times on the same model without worrying
# about the overhead.
# `force=true` allows us to add new names if we know new variabldes/constraints added.
function set_names!(fnm::FullNetworkModel; force=false)
    if force || !_has_names(fnm)
        for (name, array) in object_dictionary(fnm.model)
            _set_names!(array, name)
        end
    end
end

# if any variable/constraint in model has names, assume they all do
function _has_names(fnm::FullNetworkModel)
    first_container = first(values(object_dictionary(fnm.model)))
    first_item = first(first_container)
    return !isempty(JuMP.name(first_item))
end

function _set_names!(arr::AbstractArray, key::Symbol)
    for i in eachindex(arr)
        @inbounds JuMP.set_name(arr[i], _name(key, Tuple(i)))
    end
end

# For DenseAxisArrays `eachindex` doesn't use the names indexes, so use `axes` directly.
function _set_names!(arr::JuMP.Containers.DenseAxisArray, key::Symbol)
    for i in Iterators.product(axes(arr)...)
        @inbounds JuMP.set_name(arr[i...], _name(key, i))
    end
end

# match JuMP's naming style, which has no spaces in indexes
_name(base, idxs::Tuple) = string(base, "[", join(idxs, ","), "]")

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
