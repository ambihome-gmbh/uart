defmodule Porty.MixProject do
  use Mix.Project

  def project do
    [
      app: :uart,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers,
      deps: deps(),
      releases: [
        uart_ex: [
            applications: [uart: :permanent],
            steps: [
                :assemble
            ],
            include_erts: System.get_env("MIX_TARGET_INCLUDE_ERTS")
        ],
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.6"}
    ]
  end
end
