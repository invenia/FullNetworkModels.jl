module InHouseFNM

using Compat: only
using Dates
using JuMP
using PowerSystems

# We use -9999 as the code for the market-wide reserve zone in accordance with FNDataPrep
const MARKET_WIDE_ZONE = -9999

# Utility functions
include("utils/api.jl")
include("utils/internal.jl")
include("utils/write.jl")

# Model functions
include("model/constraints.jl")
include("model/objectives.jl")
include("model/variables.jl")

# Templates
include("templates/unit_commitment.jl")

# API functions
export FullNetworkModel
export get_noload_cost
export get_regulation_cost
export get_spinning_cost
export get_startup_cost
export get_on_sup_cost
export get_off_sup_cost
export get_generator_forecast
export get_initial_time
export get_offer_curves
export get_operating_reserve_requirements
export get_pmax
export get_pmin
export get_regmax
export get_regmin
export get_regulation_requirements
export get_reserve_zones
export get_unit_codes
export has_constraint
export has_variable

# Variable functions
export add_ancillary_services!
export add_commitment!
export add_thermal_generation!

# Constraint functions
export ancillary_service_limits!
export generation_limits!
export operating_reserve_requirements!
export regulation_requirements!

# Objective functions
export ancillary_service_costs!
export thermal_variable_cost!
export thermal_noload_cost!

# Templates
export unit_commitment

end
