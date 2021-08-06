using FullNetworkModels
using Documenter

makedocs(;
    modules=[FullNetworkModels],
    authors="Invenia Technical Computing Corporation",
    repo="https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/blob/{commit}{path}#{line}",
    sitename="FullNetworkModels.jl",
    format=Documenter.HTML(; prettyurls=false),
    pages=[
        "Home" => "index.md",
        "Notation" => "notation.md",
        "API" => map(
            p -> first(p) => joinpath("api", last(p)),
            [
                "Types" => "types.md",
                "Formulation Templates" => "templates.md",
                "Modelling" => "modelling.md",
                "Feasibility Checks" => "feasibility.md",
                "Accessors" => "accessors.md",
                "Internals" => "internals.md"
            ]
        ),
        "Contributing" => "contributing.md",
    ],
    strict=true,
    checkdocs=:exports,
)
