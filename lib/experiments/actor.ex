defmodule Actor do
  def start(name) do
    spawn(fn -> loop(name) end)
  end

  defp loop(name)do
  receive do
    :tick ->
      IO.puts("#{name} received  a tick! WeGüldisch")
      loop(name)
    end
  end
end
