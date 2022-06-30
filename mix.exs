defmodule RequestCache.MixProject do
  use Mix.Project

  def project do
    [
      app: :request_cache_plug,
      version: "0.2.1",
      elixir: "~> 1.12",
      description: "Plug to cache requests declaratively for either GraphQL or Phoenix, this plug is intended to short circuit all json/decoding or parsing a server would normally do",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
        preferred_cli_env: [
          coveralls: :test,
          "coveralls.detail": :test,
          "coveralls.post": :test,
          "coveralls.html": :test
        ]
      ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {RequestCache.Application, []},
      extra_applications: (if Mix.env() in [:test, :dev], do: [:con_cache, :logger], else: [:logger])
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:absinthe, "~> 1.4", optional: true},
      {:absinthe_plug, "~> 1.5", optional: true},
      {:con_cache, "~> 1.0", optional: true},
      {:plug, "~> 1.13"},

      {:jason, "~> 1.0", only: [:test, :dev]},
      {:ex_doc, ">= 0.0.0", only: :dev},

      {:telemetry, "~> 1.1"},
      {:telemetry_metrics, "~> 0.6.1"},

      {:excoveralls, "~> 0.10", only: :test},
      {:credo, "~> 1.6", only: [:test, :dev], runtime: false},
      {:blitz_credo_checks, "~> 0.1", only: [:test, :dev], runtime: false}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
