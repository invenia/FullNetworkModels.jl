"""
    _get_unit_codes(gentype::Type{<:Generator}, system::System) -> Vector{Int}

Returns the unit codes of all generators under type `gentype`.
"""
function _get_unit_codes(gentype::Type{<:Generator}, system::System)
    return parse.(Int, get_name.(get_components(gentype, system)))
end

"""
    _has_commitment(fnm::FullNetworkModel) -> Bool

Returns `true` if `fnm` has commitment variables and `false` otherwise.
"""
function _has_commitment(fnm::FullNetworkModel)
    unit_codes = _get_unit_codes(ThermalGen, fnm.system)
    # Return true if a variable named `u` exists and is binary
    return variable_by_name(fnm.model, "u[$(unit_codes[1]),1]") !== nothing &&
        is_binary(fnm.model[:u].data[1, 1])
end
