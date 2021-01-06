using FullNetworkModels
using Documenter

makedocs(;
    modules=[FullNetworkModels],
    authors="Invenia Technical Computing Corporation",
    repo="https://gitlab.invenia.ca/invenia/research/FullNetworkModels.jl/blob/{commit}{path}#L{line}",
    sitename="FullNetworkModels.jl",
    format=Documenter.HTML(;
        prettyurls=false,
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
    ],
    strict=true,
    checkdocs=:exports,
)
