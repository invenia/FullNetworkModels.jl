module FullNetworkModels

using Compat: only
using Dates
using JuMP
using PowerSystems

# We use -9999 as the code for the market-wide reserve zone in accordance with FNDataPrep
const MARKET_WIDE_ZONE = -9999

# Type
include("fnm.jl")

# Utility functions
include("utils/internal.jl")
include("utils/write.jl")
include("utils/accessors.jl")

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
export get_generator_forecast
export get_initial_commitment
export get_initial_downtime
export get_initial_generation
export get_initial_time
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
export add_ancillary_services!
export add_commitment!
export add_startup_shutdown!
export add_thermal_generation!

# Constraint functions
export ancillary_service_limits!
export energy_balance!
export generation_limits!
export operating_reserve_requirements!
export ramp_rates!
export regulation_requirements!

# Objective functions
export ancillary_service_costs!
export thermal_noload_cost!
export thermal_startup_cost!
export thermal_variable_cost!

# Templates
export unit_commitment

end
