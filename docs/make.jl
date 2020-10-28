using InHouseFNM
using Documenter

makedocs(;
    modules=[InHouseFNM],
    authors="Invenia Technical Computing Corporation",
    repo="https://gitlab.invenia.ca/invenia/research/InHouseFNM.jl/blob/{commit}{path}#L{line}",
    sitename="InHouseFNM.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API" => "api.md",
    ],
    strict=true,
    checkdocs=:exports,
)
