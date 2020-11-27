defmodule Toolbox do
  @spec enum(list()) :: map
  def enum(lst) do
    lst
    |> Enum.with_index(1)
    |> Enum.map(fn {k, v} -> {v, k} end)
    |> Map.new()
  end
end
