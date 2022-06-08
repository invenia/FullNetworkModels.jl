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
    _variable_cost(model::Model, names, datetimes, n_blocks, Λ, v, sense) -> AffExpr

Defines the expression of a variable cost to be added in the objective function.

Arguments:
 - `model::Model`: the JuMP model that contains the variables to be used.
 - `names`: the unit codes, bid names, or similar that act as indices.
 - `datetimes`: the time periods considered.
 - `Λ`: The offer/bid prices per block.
 - `v`: The name of the variable to be considered in the cost, e.g. `:p` for generation.
 - `sense`: constant multiplying the variable cost; should be 1 or -1 (i.e. if it's a
   positive or negative expression).
"""
function _variable_cost(model::Model, names, datetimes, n_blocks, Λ, v, sense)
    v_aux = model[Symbol(v, :_aux)]
    variable_cost = AffExpr(0.0)
    for n in names, t in datetimes, q in 1:n_blocks[n, t]
        # Faster version of `variable_cost += Λ[n, t][q] * v_aux[n, t, q]`
        add_to_expression!(variable_cost, Λ[n, t][q], v_aux[n, t, q])
    end
    # Apply sense to expression - same as `variable_cost *= sense`
    map_coefficients_inplace!(x -> sense * x, variable_cost)
    return variable_cost
end

"""
    _obj_thermal_linear_cost(fnm::FullNetworkModel, var::Symbol, f)

Adds a linear cost (cost * variable) to the objective, where the cost is fetched by function
`f` and the variable is named `var` within `fnm.model`.
"""
function _obj_thermal_linear_cost!(fnm::FullNetworkModel, var::Symbol, f)
    model = fnm.model
    cost = _keyed_to_dense(f(fnm.system))
    x = model[var]
    obj_cost = AffExpr()
    for (g, t) in eachindex(x)
        add_to_expression!(obj_cost, cost[g, t], x[g, t])
    end
    _add_to_objective!(model, obj_cost)
    return fnm
end

function _obj_static_cost!(
    fnm::FullNetworkModel, var::Symbol, field::Symbol;
    unit_codes=keys(get_generators(fnm.system))
)
    model = fnm.model
    cost = map(get_generators(fnm.system)) do gen
        getproperty(gen, field)
    end
    x = model[var]
    obj_cost = AffExpr()
    for g in unit_codes, t in fnm.datetimes
        add_to_expression!(obj_cost, cost[g], x[g, t])
    end
    _add_to_objective!(model, obj_cost)
    return fnm
end

"""
    _curve_properties(curves; blocks=false) -> DenseAxisArray, DenseAxisArray, DenseAxisArray

Returns DenseAxisArrays for several properties of offer/bid curves, namely the prices, block
MW limits and number of blocks for each component in each time period. All arrays have unit
codes/bid names and datetimes as axes, respectively. The kwarg `blocks` indicates if the
curve is just a series of blocks, meaning the MW values represent the size of the blocks
instead of the cumulative MW value in the curve.
"""
function _curve_properties(curves; blocks=false)
    prices = map(x -> first.(x), curves)
    limits = map(x -> last.(x), curves)
    n_blocks = map(length, limits)
    if !blocks
        # Change curve MW values to block MW limits - e.g. if the MW values are
        # (50, 100, 200), the corresponding MW limits of each block are (50, 50, 100).
        for lim in limits, q in length(lim):-1:2
            @inbounds lim[q] -= lim[q - 1]
        end
    end
    return prices, limits, n_blocks
end

"""
    Slacks(values)

Represents the slack penalties for each soft constraint.

The value `nothing` means "no slack" i.e. a hard constraint.

# Examples
- All values are `nothing` by default:
  ```julia
  julia> Slacks()
  Slacks:
    energy_balance = nothing
    ramp_rates = nothing
    ancillary_requirements = nothing
  ```

- If `values` is a single value (including `nothing`), set all slack penalties to that value:
  ```julia
  julia> Slacks(1e-3)
  Slacks:
    energy_balance = 0.001
    ramp_rates = 0.001
    ancillary_requirements = 0.001
  ```

- If `values` is a `Pair` or collection of `Pair`s, then the values are set according to the
  specifications in the pairs:
  ```julia
  julia> Slacks(:ramp_rates => 1e-3)
  Slacks:
    energy_balance = nothing
    ramp_rates = 0.001
    ancillary_requirements = nothing

  julia> Slacks([:ramp_rates => 1e-3, :ancillary_requirements => 1e-4])
  Slacks:
    energy_balance = nothing
    ramp_rates = 0.001
    ancillary_requirements = 0.0001
  ```
"""
Base.@kwdef struct Slacks
    energy_balance::Union{Float64, Nothing}=nothing
    ramp_rates::Union{Float64, Nothing}=nothing
    ancillary_requirements::Union{Float64, Nothing}=nothing
end

function Slacks(slacks::Union{Number,Nothing})
    names = fieldnames(Slacks)
    N = fieldcount(Slacks)
    return Slacks(NamedTuple{names}(ntuple(_ -> slacks, N)))
end
Slacks(slack::Pair{Symbol}) = Slacks(tuple(slack))
Slacks(itr...) = Slacks(NamedTuple(itr...))
Slacks(nt::NamedTuple) = Slacks(; nt...)
Slacks(sl::Slacks) = sl

function Base.show(io::IO, sl::Slacks)
    print(io, "Slacks(")
    vals = map(fieldnames(Slacks)) do x
        string(x, "=", getfield(sl, x))
    end
    join(io, vals, ", ")
    print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/plain", sl::Slacks)
    print(io, "Slacks:")
    foreach(fieldnames(Slacks)) do x
        print(io, "\n")
        print(io, "  ", x, " = ", getfield(sl, x))
    end
end

function _keyed_to_dense(arr)
    return DenseAxisArray(arr, axiskeys(arr)...)
end
