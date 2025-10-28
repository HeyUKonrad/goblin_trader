defmodule Goblin do
  use GenServer
  require Logger

  @moduledoc """
  An autonomous goblin agent that trades, moves, and makes decisions.
  Each goblin is its own process with independent state and goals.
  """

  # ->> PUBLIC API <<-

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
  end

  def get_state(id) do
    GenServer.call(via_tuple(id), :get_state)
  end

  # ->> GENSERVER CALLBACKS <<-

  @impl true
  def init(opts) do
    state = %{
      id: Keyword.fetch!(opts, :id),
      position: Keyword.fetch!(opts, :position),
      inventory: %{gold: 10, food: 5, wood: 0},
      energy: 100,
      personality: Keyword.get(opts, :personality, :balanced),
      goal: nil,
      tick: 0
    }

    Logger.debug("Goblin #{state.id} spawned at #{inspect(state.position)}")
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    new_state =
      state
      |> Map.update!(:tick, &(&1 + 1))
      |> consume_energy()
      |> decide_action()
      |> execute_action()

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:trade_offer, from_id, offer}, _from, state) do
    decision = consider_trade(state, from_id, offer)
    {:reply, decision, state}
  end

  @impl true
  def handle_cast({:complete_trade, items_gained, items_lost}, state) do
    new_inventory =
      state.inventory
      |> Map.merge(items_gained, fn _k, v1, v2 -> v1 + v2 end)
      |> Map.merge(items_lost, fn _k, v1, v2 -> v1 - v2 end)

    {:noreply, %{state | inventory: new_inventory}}
  end

  # ->> DECISION MAKING (Rules of Behavior) <<-

  defp decide_action(state) do
    cond do
      # Survival: Low energy means find food
      state.energy < 30 ->
        Map.put(state, :goal, {:find_food, urgent: true})

      # Economic: Low on gold, seek trade
      state.inventory.gold < 5 ->
        Map.put(state, :goal, {:seek_trade, resource: :wood})

      # Opportunistic: Based on personality
      state.personality == :greedy ->
        Map.put(state, :goal, {:seek_trade, resource: :gold})

      # Social: Wander and explore
      true ->
        Map.put(state, :goal, :wander)
    end
  end

  defp execute_action(%{goal: {:find_food, _}} = state) do
    # Check if food nearby, try to move toward it
    case WorldServer.find_nearest(state.position, :food) do
      nil ->
        move_random(state)

      target_pos ->
        move_toward(state, target_pos)
    end
  end

  defp execute_action(%{goal: {:seek_trade, resource: resource}} = state) do
    # Find nearby goblins and attempt trade
    nearby = WorldServer.get_nearby_goblins(state.position, radius: 3)

    case nearby do
      [] ->
        move_random(state)

      goblins ->
        attempt_trade(state, Enum.random(goblins), resource)
    end
  end

  defp execute_action(%{goal: :wander} = state) do
    move_random(state)
  end

  defp execute_action(state), do: state

  # ->> ACTIONS <<-

  defp move_random(state) do
    {x, y} = state.position
    direction = Enum.random([{-1, 0}, {1, 0}, {0, -1}, {0, 1}])
    {dx, dy} = direction
    new_pos = {x + dx, y + dy}

    case WorldServer.move_goblin(state.id, state.position, new_pos) do
      :ok ->
        %{state | position: new_pos}

      :blocked ->
        state
    end
  end

  defp move_toward(state, {target_x, target_y}) do
    {x, y} = state.position

    direction =
      cond do
        target_x > x -> {1, 0}
        target_x < x -> {-1, 0}
        target_y > y -> {0, 1}
        target_y < y -> {0, -1}
        true -> {0, 0}
      end

    {dx, dy} = direction
    new_pos = {x + dx, y + dy}

    case WorldServer.move_goblin(state.id, state.position, new_pos) do
      :ok -> %{state | position: new_pos}
      :blocked -> move_random(state)
    end
  end

  defp attempt_trade(state, target_id, _resource) do
    # Simple trade logic: offer gold for food if hungry
    offer = %{give: %{gold: 2}, want: %{food: 1}}

    case GenServer.call(via_tuple(target_id), {:trade_offer, state.id, offer}) do
      :accept ->
        Logger.info("Goblin #{state.id} completed trade with #{target_id}")
        GenServer.cast(via_tuple(state.id), {:complete_trade, offer.want, offer.give})
        GenServer.cast(via_tuple(target_id), {:complete_trade, offer.give, offer.want})

      :reject ->
        Logger.debug("Trade rejected")
    end

    state
  end

  defp consider_trade(state, _from_id, offer) do
    # Simple evaluation: accept if we have resources and want what's offered
    can_afford =
      Enum.all?(offer.want, fn {resource, amount} ->
        Map.get(state.inventory, resource, 0) >= amount
      end)

    wants_it =
      Enum.any?(offer.give, fn {resource, amount} ->
        resource == :food and state.energy < 50 or
          resource == :gold and state.inventory.gold < 10
      end)

    if can_afford and wants_it, do: :accept, else: :reject
  end

  # ->> HELPERS <<-

  defp consume_energy(state) do
    # Lose 1 energy per tick, gain energy if eating food
    new_energy = max(0, state.energy - 1)

    if new_energy < 50 and state.inventory.food > 0 do
      %{
        state
        | energy: min(100, new_energy + 20),
          inventory: Map.update!(state.inventory, :food, &(&1 - 1))
      }
    else
      %{state | energy: new_energy}
    end
  end

  defp via_tuple(id), do: {:via, Registry, {GoblinRegistry, id}}
end
