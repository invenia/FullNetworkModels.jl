"""
    FullNetworkModel

Structure containing all the information on the full network model. Contains the JuMP
`model` and the PowerSystems `system`.

A FullNetworkModel can be initialized using `FullNetworkModel(system::System, solver)`,
which creates an empty JuMP model related to `system` using the desired `solver`.
"""
struct FullNetworkModel
    model::Model
    system::System
end
function FullNetworkModel(system::System, solver)
    return FullNetworkModel(Model(solver), system)
end

# This is necessary to avoid printing a lot of stuff due to PowerSystems printing
function Base.show(io::IO, fnm::FullNetworkModel)
    println(io, "FullNetworkModel")
    println(io, "Model formulation: $(num_variables(fnm.model)) variables")
    println(io, "System: $(length(get_components(Component, fnm.system))) components, $(get_forecasts_horizon(fnm.system)) time periods")
    return nothing
end

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

"""
    get_unit_codes(gentype::Type{<:Generator}, system::System) -> Vector{Int}

Returns the unit codes of all generators under type `gentype`.
"""
function get_unit_codes(gentype::Type{<:Generator}, system::System)
    return parse.(Int, get_name.(get_components(gentype, system)))
end

"""
    get_initial_time(system::System) -> DateTime

Returns the initial `DateTime` of the forecasts in `system`.
"""
PowerSystems.get_initial_time(system::System) = only(get_forecast_initial_times(system))

"""
    get_generator_forecast(system::System, label::Symbol; inner_label=:null) -> Dict

Returns a dictionary with the forecasts for `label` stored in `system`. The keys of the
dictionary are the unit codes. If there forecast has a label within a label, `inner_label`
should be also used.
"""
function get_generator_forecast(system::System, label::Symbol, inner_label=:null)
    unit_codes = get_unit_codes(ThermalGen, system)
    initial_time = only(get_forecast_initial_times(system))
    n_periods = get_forecasts_horizon(system)
    forec = Dict()
    for unit in unit_codes
        gen = get_component(ThermalGen, system, string(unit))
        unit_forecasts = values(
            get_forecast(
                Deterministic, gen, initial_time, "get_thermal_params", n_periods
            ).data
        )
        forec[unit] = if inner_label == :null
            getproperty.(unit_forecasts, label)
        else
            getproperty.(getproperty.(unit_forecasts, label), inner_label)
        end
    end
    return forec
end

"""
    get_pmin(system::System) -> Dict

Returns Pmin, i.e., the minimum power outputs of the generators in `system`.
"""
get_pmin(system::System) = get_generator_forecast(system, :active_power_min)

"""
    get_pmax(system::System) -> Dict

Returns Pmax, i.e., the maximum power outputs of the generators in `system`.
"""
get_pmax(system::System) = get_generator_forecast(system, :active_power_max)

"""
    get_regmin(system::System) -> Dict

Returns the minimum power outputs with regulation of the generators in `system`.
"""
get_regmin(system::System) = get_generator_forecast(system, :regulation_min)

"""
    get_regmax(system::System) -> Dict

Returns the maximum power outputs with regulation of the generators in `system`.
"""
get_regmax(system::System) = get_generator_forecast(system, :regulation_max)

"""
    get_cost_regulation(system::System) -> Dict

Returns the costs of regulation offered by the generators in `system`.
"""
get_cost_regulation(system::System) = get_generator_forecast(system, :asm_costs, :reg)

"""
    get_cost_spinning(system::System) -> Dict

Returns the costs of spinning reserve offered by the generators in `system`.
"""
get_cost_spinning(system::System) = get_generator_forecast(system, :asm_costs, :spin)

"""
    get_cost_supp_on(system::System) -> Dict

Returns the costs of online supplemental reserve offered by the generators in `system`.
"""
get_cost_supp_on(system::System) = get_generator_forecast(system, :asm_costs, :sup)

"""
    get_cost_supp_off(system::System) -> Dict

Returns the costs of offline supplemental reserve offered by the generators in `system`.
"""
get_cost_supp_off(system::System) = get_generator_forecast(system, :asm_costs, :sup_off)
