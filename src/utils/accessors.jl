"""
    has_variable(model::Model, var) -> Bool

Returns `true` if `model` contains a variable named `var` and `false` otherwise.
"""
function has_variable(model::Model, var::Symbol)
    obj_dict = object_dictionary(model)
    return haskey(obj_dict, var) && eltype(obj_dict[var]) <: VariableRef
end
has_variable(model::Model, var::String) = has_variable(model, Symbol(var))

"""
    has_constraint(model::Model, con) -> Bool

Returns `true` if `model` contains a constraint named `con` and `false` otherwise.
"""
function has_constraint(model::Model, con::Symbol)
    obj_dict = object_dictionary(model)
    return haskey(obj_dict, con) && eltype(obj_dict[con]) <: ConstraintRef
end
has_constraint(model::Model, con::String) = has_constraint(model, Symbol(con))

const _PTDF_THRESHOLD = 1e-4
"""
    _threshold(shift_factor, threshold=$_SF_THRESHOLD)

Allows to threshold the shift factor values (PTDF/LODF) such that
|x| < threshold is set to 0.0. This is useful to improve the computational performance of
OPF as PTDF does not need to be as precise after LODFs are calculated so they can safely be
thresholded by a small threshold (e.g. 1e-4). This can also be used to comply with ISOs'
practice to threshold the shift factor values.

See measurements on safe PTDF thresholding in
https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/-/merge_requests/128
"""
function _threshold(shift_factor::KeyedArray, threshold::Float64=_PTDF_THRESHOLD)
    shift_factor_thresholded = replace!(x -> abs(x) < threshold ? 0.0 : x, shift_factor)
    return shift_factor_thresholded
end
