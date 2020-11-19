"""
    _add_to_objective!(model::Model, expr)

Adds the expression `expr` to the current objective of `model`.
"""
function _add_to_objective!(model::Model, expr)
    obj = objective_function(model)
    add_to_expression!(obj, expr)
    @objective(model, Min, obj)
    return model
end

"""
    _offer_curve_properties(offer_curves, n_periods) -> Dict, Dict, Dict

Returns dictionaries for several properties of offer curves, namely the prices, block
generation limits and number of blocks for each generator in each time period. All
dictionaries have the unit codes as keys.
"""
function _offer_curve_properties(offer_curves, n_periods)
    prices = Dict{Int, Vector{Vector{Float64}}}()
    limits = Dict{Int, Vector{Vector{Float64}}}()
    n_blocks = Dict{Int, Vector{Int}}()
    for (g, offer_curve) in offer_curves
        prices[g] = [first.(offer_curve[i]) for i in 1:n_periods]
        limits[g] = [last.(offer_curve[i]) for i in 1:n_periods]
        n_blocks[g] = length.(limits[g])
    end
    # Change block MW values to block limits - e.g. if the MW values are (50, 100, 200),
    # the corresponding limits of each block are (50, 50, 100).
    for g in keys(n_blocks), t in 1:n_periods, q in n_blocks[g][t]:-1:2
        limits[g][t][q] -= limits[g][t][q - 1]
    end
    return prices, limits, n_blocks
end
