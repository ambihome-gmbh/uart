defmodule Uart.MixProject do
  use Mix.Project

  def project do
    [
      app: :uart,
      version: "0.2.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_env: make_env(),
      make_clean: ["clean"],
      make_executable: make_executable(),
      make_makefile: "Makefile",
      dialyzer: dialyzer(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.9"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp make_env, do: %{}

  defp make_executable do
    case :os.type() do
      {:win32, _} -> raise("better not use windows with this")
      _ -> :default
    end
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      list_unused_filters: true
    ]
  end
end
