using AxisKeys
using Dates
using ElectricityMarkets: MISO
using ElectricityMarkets.TestUtils: FakeGrid
using FullNetworkDataPrep.TestUtils: build_test_system
using FullNetworkDataPrep: DA, RT
using FullNetworkModels
using FullNetworkModels: Slacks
using FullNetworkSystems
using FullNetworkSystems: System, get_must_run, get_load, Branch
using HiGHS
using JuMP.Containers: DenseAxisArray
using JuMP
using MathOptInterface: TerminationStatusCode
using Memento.TestUtils: @test_log
using Test
using TimeSeries

const FNM = FullNetworkModels
const TEST_SYSTEM = build_test_system(MISO, DA)
const TEST_SYSTEM_RT = build_test_system(MISO, RT)
const TEST_LODF_DICT = get_lodfs(TEST_SYSTEM)
const TEST_CONTINGENCIES = keys(TEST_LODF_DICT)

# Name individual variables and constraints to allow us testing our expressions using `sprint`
#
# Short-circuit if any names already present, assuming if any var/con has a name then they
# all do; this allows us to call `set_names!` many times on the same model without worrying
# about the overhead.
# `force=true` allows us to add new names if we know new variabldes/constraints added.
function set_names!(fnm::FullNetworkModel; force=false)
    if force || !has_names(fnm)
        for (name, array) in object_dictionary(fnm.model)
            _set_names!(array, name)
        end
    end
end

function has_names(fnm::FullNetworkModel)
    for container in values(object_dictionary(fnm.model))
        for item in container
            !isempty(JuMP.name(item)) && return true
        end
    end
    return false
end

function _set_names!(arr::AbstractArray, key::Symbol)
    for i in _eachnamedindex(arr)
        @inbounds JuMP.set_name(arr[i...], _name(key, i))
    end
end

# Iterate tuples containing the named indices of the given array.
_eachnamedindex(arr::JuMP.Containers.SparseAxisArray) = Iterators.map(Tuple, eachindex(arr))
_eachnamedindex(arr::JuMP.Containers.DenseAxisArray) = Iterators.product(axes(arr)...)

# Match JuMP's naming style which has no spaces in indices.
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
