# Define functions so that `latex` can be dispatched over them
function var_bids! end
function var_commitment! end
function var_thermal_generation! end
function _var_startup_shutdown! end
function _con_startup_shutdown! end
function _var_ancillary_services! end
function _var_reg_commitment! end
function _con_reg_commitment! end

function latex(::typeof(var_thermal_generation!))
    return """
    ``p_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    var_thermal_generation!(fnm::FullNetworkModel)

Adds the thermal generation variables `p` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered:

$(latex(var_thermal_generation!))
"""
function var_thermal_generation!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    fnm.model[:p] = @variable(fnm.model, [g in unit_codes, t in fnm.datetimes], lower_bound=0)
    return fnm
end

function latex(::typeof(var_commitment!))
    return """
    ``u_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
    """
end

"""
    var_commitment!(fnm::FullNetworkModel)

Adds the binary commitment variables `u` indexed, respectively, by the unit codes of the
thermal generators in `system` and by the time periods considered:

$(latex(var_commitment!))
"""
function var_commitment!(fnm::FullNetworkModel)
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    fnm.model[:u] = @variable(fnm.model, [g in unit_codes, t in fnm.datetimes], Bin)
    return fnm
end

function latex(::typeof(_var_startup_shutdown!))
    return """
        ``0 \\leq v_{g, t} \\leq 1, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``0 \\leq w_{g, t} \\leq 1, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function latex(::typeof(_con_startup_shutdown!))
    return """
        ``u_{g, t} - u_{g, t - 1} = v_{g, t} - w_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T} \\setminus \\{1\\}`` \n
        ``u_{g, 1} - U^{0}_{g} = v_{g, 1} - w_{g, 1}, \\forall g \\in \\mathcal{G}``
        """
end

"""
    var_startup_shutdown!(fnm::FullNetworkModel)

Adds the variables `v` and `w` representing the start-up and shutdown of generators,
respectively, indexed by the unit codes of the thermal generators in `system` and by the
time periods considered:

$(latex(_con_startup_shutdown!))
$(latex(_var_startup_shutdown!))
"""
function var_startup_shutdown!(fnm::FullNetworkModel)
    model = fnm.model
    system = fnm.system
    datetimes = fnm.datetimes
    unit_codes = get_unit_codes(ThermalGen, system)
    _var_startup_shutdown!(model, unit_codes, datetimes)
    _con_startup_shutdown!(model, system, unit_codes, datetimes)
    return fnm
end

function _var_startup_shutdown!(model::Model, unit_codes, datetimes)
    model[:v] = @variable(model, [g in unit_codes, t in datetimes], lower_bound=0, upper_bound=1)
    model[:w] = @variable(model, [g in unit_codes, t in datetimes], lower_bound=0, upper_bound=1)
    return model
end

function _con_startup_shutdown!(model::Model, system, unit_codes, datetimes)
    # Get variables and parameters for better readability
    u = model[:u]
    v = model[:v]
    w = model[:w]
    U0 = get_initial_commitment(system)
    Δh = Hour(_get_resolution_in_minutes(system) / 60) # assume hourly resolution
    h1 = first(datetimes)
    # Add the constraints that model the start-up and shutdown variables
    model[:startup_shutdown_definition] = @constraint(
        model,
        [g in unit_codes, t in datetimes[2:end]],
        u[g, t] - u[g, t - Δh] == v[g, t] - w[g, t]
    )
    model[:startup_shutdown_definition_initial] = @constraint(
        model,
        [g in unit_codes],
        u[g, h1] - U0[g] == v[g, h1] - w[g, h1]
    )
    return model
end

function latex(::typeof(_var_ancillary_services!))
    return """
        ``r^{\\text{reg}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{spin}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{on-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}`` \n
        ``r^{\\text{off-sup}}_{g, t} \\geq 0, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function latex(::typeof(_var_reg_commitment!))
    return """
        ``u^{\\text{reg}}_{g, t} \\in \\{0, 1\\}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

function latex(::typeof(_con_reg_commitment!))
    return """
        ``u^{\\text{reg}}_{g, t} \\leq u_{g, t}, \\forall g \\in \\mathcal{G}, t \\in \\mathcal{T}``
        """
end

"""
    var_ancillary_services!(fnm::FullNetworkModel)

Adds the ancillary service variables indexed, respectively, by the unit codes of the thermal
generators in system and by the datetimes considered.

The variables include regulation, spinning, online supplemental, and offline supplemental
reserves, and are name `r_reg`, `r_spin`, `r_on_sup` and `r_off_sup`.

$(latex(_var_ancillary_services!))

For UC, there is the additional variable regulation commitment, named `u_reg`.

$(latex(_var_reg_commitment!))
$(latex(_con_reg_commitment!))
"""
function var_ancillary_services!(fnm::FullNetworkModel{<:UC})
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    _var_ancillary_services!(fnm.model, unit_codes, fnm.datetimes)
    _var_reg_commitment!(fnm.model, unit_codes, fnm.datetimes)
    _con_reg_commitment!(fnm.model, unit_codes, fnm.datetimes)
    return fnm
end

function var_ancillary_services!(fnm::FullNetworkModel{<:ED})
    unit_codes = get_unit_codes(ThermalGen, fnm.system)
    _var_ancillary_services!(fnm.model, unit_codes, fnm.datetimes)
    return fnm
end

function _var_ancillary_services!(model::Model, unit_codes, datetimes)
    model[:r_reg] = @variable(model, [g in unit_codes, t in datetimes], lower_bound=0)
    model[:r_spin] = @variable(model, [g in unit_codes, t in datetimes], lower_bound=0)
    model[:r_on_sup] = @variable(model, [g in unit_codes, t in datetimes], lower_bound=0)
    model[:r_off_sup] = @variable(model, [g in unit_codes, t in datetimes], lower_bound=0)
    return model
end

function _var_reg_commitment!(model::Model, unit_codes, datetimes)
    model[:u_reg] = @variable(model, [g in unit_codes, t in datetimes], Bin)
    return model
end

function _con_reg_commitment!(model::Model, unit_codes, datetimes)
    # We add a constraint here because it is part of the basic definition of `u_reg`
    u = model[:u]
    u_reg = model[:u_reg]
    @constraint(model, [g in unit_codes, t in datetimes], u_reg[g, t] <= u[g, t])
    return model
end

function latex(::typeof(var_bids!))
    return """
    ``inc_{g, t} \\geq 0, \\forall i \\in \\mathcal{I}, t \\in \\mathcal{T}`` \n
    ``dec_{g, t} \\geq 0, \\forall d \\in \\mathcal{D}, t \\in \\mathcal{T}`` \n
    ``psd_{g, t} \\geq 0, \\forall s \\in \\mathcal{S}, t \\in \\mathcal{T}``
    """
end

"""
    var_bids!(fnm::FullNetworkModel)

Adds the virtual and price-sensitive demand bid variables indexed, respectively, by the bid
names and time periods.

$(latex(var_bids!))

The created variables are named `inc`, `dec`, `psd`.
"""
function var_bids!(fnm::FullNetworkModel)
    model = fnm.model
    datetimes = fnm.datetimes
    inc_names = get_bid_names(Increment, fnm.system)
    dec_names = get_bid_names(Decrement, fnm.system)
    psd_names = get_bid_names(PriceSensitiveDemand, fnm.system)
    model[:inc] = @variable(model, [i in inc_names, t in datetimes], lower_bound=0)
    model[:dec] = @variable(model, [d in dec_names, t in datetimes], lower_bound=0)
    model[:psd] = @variable(model, [s in psd_names, t in datetimes], lower_bound=0)
    return fnm
end
