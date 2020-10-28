module InHouseFNM

using Compat: only
using Dates
using JuMP
using PowerSystems

# Utility functions
include("utils/structs.jl")
include("utils/internal.jl")
include("utils/api.jl")

# Model functions
include("model/variables.jl")

# Templates
include("templates/unit_commitment.jl")

# API functions
export FullNetworkModel

# Model functions
export add_commitment!
export add_thermal_generation!

# Templates
export unit_commitment

end
