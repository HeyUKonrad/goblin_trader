defmodule Clock do
  use GenServer

  def start_link(targets, interval_ms \\ 1000) do
    GenServer.start_link(__MODULE__, {targets, interval_ms}, name: __MODULE__)
  end

  @impl true
  def init({targets, interval_ms}) do
    schedule_tick(interval_ms)
    {:ok, {targets, interval_ms}}
  end

  @impl true
  def handle_info(:tick, {targets, interval_ms}) do
    Enum.each(targets, fn pid ->
        send(pid, :tick)
      end)
    schedule_tick(interval_ms)
    {:noreply, {targets, interval_ms}}
  end

  defp schedule_tick(interval_ms), do: Process.send_after(self(), :tick, interval_ms)
end
