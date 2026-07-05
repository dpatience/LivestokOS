[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["apps/*/priv/*/migrations"],
  inputs: [
    "*.{ex,exs}",
    "config/**/*.{ex,exs}",
    "apps/*/{config,lib,test}/**/*.{ex,exs}",
    "apps/*/priv/*/seeds.exs"
  ]
]
