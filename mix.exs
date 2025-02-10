defmodule Porty.MixProject do
  use Mix.Project

  def project do
    [
      app: :uart,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers,
      make_clean: ["clean"],
      make_executable: make_executable(),
      make_makefile: "Makefile",
      start_permanent: Mix.env() == :prod,
      dialyzer: dialyzer(),
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
      {:elixir_make, "~> 0.9"},
      {:typed_struct, "~> 0.3.0"}
    ]
  end

  defp make_executable do
    case :os.type() do
      {:win32, _} ->
        "mingw32-make"

      _ ->
        :default
    end
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      list_unused_filters: true
    ]
  end
end
