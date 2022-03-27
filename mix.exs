defmodule RequestCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :request_cache_plug,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:absinthe, "~> 1.7", optional: true},
      {:con_cache, "~> 1.0", optional: true},
      {:plug, "~> 1.13"},

      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Mika Kalathil"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/mikaak/request_cache_plug"},
      files: ~w(mix.exs README.md CHANGELOG.md LICENSE lib config)
    ]
  end

  defp docs do
    [
      main: "RequestCache",
      source_url: "https://github.com/mikaak/request_cache_plug",

      groups_for_modules: [
        "Middleware/Plugs": [
          RequestCache.Plug,
          RequestCache.Middleware
        ]
      ]
    ]
  end
end
