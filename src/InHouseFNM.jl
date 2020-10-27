module InHouseFNM

using JuMP
using PowerSystems

# Utility functions
include("utils/api.jl")
include("utils/internal.jl")

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
