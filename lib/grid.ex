defmodule Grid do
  def new(width, height, default \\ :empty) do
    for x <- 0..(width - 1),
        y <- 0..(height - 1),
        into: %{},
        do: {{x, y}, default}
  end

  def set(grid, {x, y}, value), do: Map.put(grid, {x, y}, value)
  def get(grid, {x, y}), do: Map.get(grid, {x, y})
end
