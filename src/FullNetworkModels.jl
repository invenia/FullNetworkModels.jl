module FullNetworkModels

using AxisKeys
using AxisKeys: sortkeys
using Dates
using Dictionaries: Dictionary
using ElectricityMarkets: Grid, MISO
using FullNetworkSystems
using JuMP
using JuMP.Containers: DenseAxisArray
using Memento
using TimerOutputs

const LOGGER = getlogger(@__MODULE__)

# We use -9999 as the code for the market-wide reserve zone in accordance with FNDataPrep
const MARKET_WIDE_ZONE = -9999

# Default threshold (cutoff) value for shift factors
const _SF_THRESHOLD = 1e-4

# Types
include("types/formulations.jl")
include("types/fnm.jl")

# Utility functions
include("utils/api_extensions.jl")
include("utils/internal.jl")
include("utils/write.jl")
include("utils/accessors.jl")
include("utils/feasibility_checks.jl")

# Model functions
include("model/general/constraints.jl")
include("model/general/objectives.jl")
include("model/general/variables.jl")

# Templates
include("templates/unit_commitment.jl")
include("templates/economic_dispatch.jl")

# Types
export FullNetworkModel
export UnitCommitment
export EconomicDispatch
export UC
export ED

# Templates
export economic_dispatch
export unit_commitment

export has_constraint
export has_variable

# Variable functions
export var_ancillary_services!
export var_bids!
export var_commitment!
export var_startup_shutdown!
export var_thermal_generation!
export var_nodal_net_injection!

# Constraint functions
export con_ancillary_limits!
export con_ancillary_ramp_rates!
export con_availability!
export con_energy_balance!
export con_generation_limits!
export con_generation_ramp_rates!
export con_must_run!
export con_operating_reserve_requirements!
export con_regulation_requirements!
export con_thermal_branch!

# Objective functions
export obj_ancillary_costs!
export obj_bids!
export obj_thermal_noload_cost!
export obj_thermal_startup_cost!
export obj_thermal_variable_cost!

# API extensions
export optimize!
export set_optimizer_attribute
export set_optimizer_attributes

# Miscellaneous utility functions
export basic_feasibility_checks

# API extensions
export optimize!
export set_optimizer_attribute
export set_optimizer_attributes

end
