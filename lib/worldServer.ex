defmodule World do
  use GenServer
  alias Grid

  # ->> PUBLIC API <<-

  def start_link({width, height}) do
    GenServer.start_link(__MODULE__, {width, height}, name: __MODULE__)
  end

  # ->>  API <<-

  @impl true
  def init({width, height}) do
    grid = initialize_grid(width, height)
    schedule_tick()
    {:ok, %{grid: grid, width: width, height: height, tick: 0}}
  end

  @impl true
  def handle_info(:tick, %{grid: grid, width: w, height: h, tick: t} = state) do
    new_grid = update_grid(grid)
    render(new_grid, w, h, t)
    schedule_tick()
    {:noreply, %{state | grid: new_grid, tick: t + 1}}
  end

  # ->> HELPERS <<-

  defp schedule_tick, do: Process.send_after(self(), :tick, 1000)

  def initialize_grid(width, height) do
    for x <- 0..(width - 1),
        y <- 0..(height - 1),
        into: %{},
        do: {{x, y}, if(:rand.uniform() < 0.3, do: :filled, else: :empty)}
  end

  defp update_grid(grid) do
    for {pos, val} <- grid, into: %{} do
      alive_neighbors = count_alive_neighbors(grid, pos)

      new_val =
        case {val, alive_neighbors} do
          # underpopulation
          {:filled, n} when n < 2 -> :empty
          # lives
          {:filled, n} when n in [2, 3] -> :filled
          # overpopulation
          {:filled, n} when n > 3 -> :empty
          # reproduction
          {:empty, 3} -> :filled
          # stays empty
          _ -> :empty
        end

      {pos, new_val}
    end
  end

  defp render(grid, width, height, tick) do
    IO.write(IO.ANSI.clear())
    IO.puts("Tick #{tick}")

    for y <- 0..(height - 1) do
      for x <- 0..(width - 1) do
        case grid[{x, y}] do
          :empty -> " "
          :filled -> "X"
        end
      end
      |> Enum.join("")
      |> IO.puts()
    end
  end

  defp count_alive_neighbors(grid, {x, y}) do
    neighbors = [
      {x - 1, y - 1},
      {x, y - 1},
      {x + 1, y - 1},
      {x - 1, y},
      {x + 1, y},
      {x - 1, y + 1},
      {x, y + 1},
      {x + 1, y + 1}
    ]

    Enum.count(neighbors, fn pos -> grid[pos] == :filled end)
  end
end
