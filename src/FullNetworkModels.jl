module FullNetworkModels

using Dates
using JuMP
using Memento
using PowerSystems

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

# Type
export FullNetworkModel

# Accessor functions
export get_fixed_loads
export get_generator_time_series
export get_initial_commitment
export get_initial_downtime
export get_initial_generation
export get_initial_uptime
export get_load_names
export get_minimum_downtime
export get_minimum_uptime
export get_noload_cost
export get_offer_curves
export get_off_sup_cost
export get_off_sup_providers
export get_on_sup_cost
export get_on_sup_providers
export get_operating_reserve_requirements
export get_pmax
export get_pmin
export get_ramp_rates
export get_regmax
export get_regmin
export get_regulation_cost
export get_commitment_status
export get_regulation_providers
export get_regulation_requirements
export get_reserve_zones
export get_spinning_cost
export get_spinning_providers
export get_startup_cost
export get_startup_limits
export get_unit_codes
export has_constraint
export has_variable

# Variable functions
export var_ancillary_services!
export var_commitment!
export var_startup_shutdown!
export var_thermal_generation!

# Constraint functions
export con_ancillary_limits!
export con_energy_balance!
export con_generation_limits!
export con_operating_reserve_requirements!
export con_ramp_rates!
export con_regulation_requirements!

# Objective functions
export obj_ancillary_costs!
export obj_thermal_noload_cost!
export obj_thermal_startup_cost!
export obj_thermal_variable_cost!

# Templates
export unit_commitment
export unit_commitment_soft_ramps
export unit_commitment_no_ramps

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
