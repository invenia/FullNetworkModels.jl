module FullNetworkModels

using Dates
using JuMP
using JuMP.Containers: DenseAxisArray
using Memento
using PowerSystems
using PowerSystemsExtras

const LOGGER = getlogger(@__MODULE__)

# We use -9999 as the code for the market-wide reserve zone in accordance with FNDataPrep
const MARKET_WIDE_ZONE = -9999

# Type
include("fnm.jl")

# Utility functions
include("utils/api_extensions.jl")
include("utils/internal.jl")
include("utils/write.jl")
include("utils/accessors.jl")
include("utils/feasibility_checks.jl")

# Model functions
include("model/constraints.jl")
include("model/objectives.jl")
include("model/variables.jl")

# Templates
include("templates/unit_commitment.jl")
include("templates/economic_dispatch.jl")

# Types
export FullNetworkModel
export UCED
export UC
export ED

# Accessor functions
export get_bid_curves
export get_bid_names
export get_bid_names_perbus
export get_branch_break_points
export get_branch_names
export get_branch_penalties
export get_branch_rates
export get_commitment_reg_status
export get_commitment_status
export get_fixed_loads
export get_forecast_timestamps
export get_generator_time_series
export get_initial_commitment
export get_initial_downtime
export get_initial_generation
export get_initial_uptime
export get_load_names
export get_load_names_perbus
export get_minimum_downtime
export get_minimum_uptime
export get_monitored_branches
export get_noload_cost
export get_off_sup_cost
export get_off_sup_providers
export get_offer_curves
export get_on_sup_cost
export get_on_sup_providers
export get_operating_reserve_requirements
export get_pmax
export get_pmin
export get_ramp_rates
export get_regmax
export get_regmin
export get_regulation_cost
export get_regulation_providers
export get_regulation_requirements
export get_reserve_zones
export get_spinning_cost
export get_spinning_providers
export get_startup_cost
export get_startup_limits
export get_unit_codes
export get_unit_codes_perbus
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
export con_energy_balance!
export con_generation_limits!
export con_generation_ramp_rates!
export con_operating_reserve_requirements!
export con_regulation_requirements!
export con_thermal_branch!

# Objective functions
export obj_ancillary_costs!
export obj_bids!
export obj_thermal_noload_cost!
export obj_thermal_startup_cost!
export obj_thermal_variable_cost!

# Templates
export economic_dispatch
export economic_dispatch_branch_flow_limits
export unit_commitment
export unit_commitment_soft_ramps
export unit_commitment_no_ramps
export unit_commitment_branch_flow_limits
export unit_commitment_soft_ramps_branch_flow_limits
export unit_commitment_no_ramps_branch_flow_limits

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
