# Here we extend some functions from dependencies to make the use of the package easier
# e.g. instead of having to load JuMP and call `optimize!(fnm.model)` we can just
# call `optimize!(fnm)` straight away.

JuMP.optimize!(fnm::FullNetworkModel) = optimize!(fnm.model)

JuMP.set_optimizer(fnm::FullNetworkModel, solver::Nothing; kwargs...) = nothing
function JuMP.set_optimizer(fnm::FullNetworkModel, solver; kwargs...)
    return set_optimizer(fnm.model, solver; kwargs...)
end

function JuMP.set_optimizer_attribute(fnm::FullNetworkModel, name::String, value)
    return set_optimizer_attribute(fnm.model, name, value)
end

function JuMP.set_optimizer_attributes(fnm::FullNetworkModel, pairs::Pair...)
    return set_optimizer_attributes(fnm.model, pairs...)
end

function JuMP.get_optimizer_attribute(fnm::FullNetworkModel, name::String)
    return get_optimizer_attribute(fnm.model, name)
end
