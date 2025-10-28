defmodule GoblinRules do
  @moduledoc """
  Defines the behavioral rules and decision-making logic for goblins.
  These rules create emergent behavior when many goblins interact.
  """

  # ->> SURVIVAL RULES <<-

  @doc """
  Energy drops over time. Goblins must eat to survive.
  """
  def energy_decay_rate, do: 1

  def starvation_threshold, do: 10
  def low_energy_threshold, do: 30
  def max_energy, do: 100

  def food_energy_value, do: 20

  # ->> ECONOMIC RULES <<-

  @doc """
  Trade valuation: how much goblins value different resources.
  Different personalities weight these differently.
  """
  def base_values do
    %{
      gold: 1.0,
      food: 1.5,
      # Food valued higher when low energy
      wood: 0.8
    }
  end

  def personality_modifiers(:greedy) do
    %{gold: 1.5, food: 0.8, wood: 1.0}
  end

  def personality_modifiers(:cautious) do
    %{gold: 0.8, food: 2.0, wood: 1.0}
  end

  def personality_modifiers(:balanced) do
    %{gold: 1.0, food: 1.0, wood: 1.0}
  end

  def personality_modifiers(:social) do
    %{gold: 0.7, food: 1.2, wood: 1.3}
  end

  @doc """
  Calculate if a trade is beneficial based on personality and needs.
  """
  def evaluate_trade(state, offer) do
    personality_mods = personality_modifiers(state.personality)
    base_vals = base_values()

    # Adjust food value based on current energy
    energy_multiplier = if state.energy < 40, do: 2.0, else: 1.0

    value_given =
      Enum.reduce(offer.give, 0, fn {resource, amount}, acc ->
        base = Map.get(base_vals, resource, 1.0)
        modifier = Map.get(personality_mods, resource, 1.0)
        multiplier = if resource == :food, do: energy_multiplier, else: 1.0
        acc + base * modifier * multiplier * amount
      end)

    value_received =
      Enum.reduce(offer.want, 0, fn {resource, amount}, acc ->
        base = Map.get(base_vals, resource, 1.0)
        modifier = Map.get(personality_mods, resource, 1.0)
        multiplier = if resource == :food, do: energy_multiplier, else: 1.0
        acc + base * modifier * multiplier * amount
      end)

    # Trade is beneficial if we receive more value than we give
    value_received > value_given
  end

  # ->> MOVEMENT RULES <<-

  @doc """
  Vision radius: how far goblins can see
  """
  def vision_radius(:greedy), do: 5
  def vision_radius(:cautious), do: 3
  def vision_radius(:balanced), do: 4
  def vision_radius(:social), do: 6

  @doc """
  Movement cost: energy spent per move
  """
  def movement_cost, do: 0.5

  # ->> SOCIAL RULES <<-

  @doc """
  How likely goblins are to initiate trade based on personality
  """
  def trade_initiative(:greedy), do: 0.8
  def trade_initiative(:cautious), do: 0.3
  def trade_initiative(:balanced), do: 0.5
  def trade_initiative(:social), do: 0.9

  @doc """
  Personal space: minimum distance goblins prefer to others
  """
  def personal_space(:greedy), do: 1
  def personal_space(:cautious), do: 3
  def personal_space(:balanced), do: 2
  def personal_space(:social), do: 1

  # ->> GOAL PRIORITY RULES <<-

  @doc """
  Determines action priority based on current state.
  Returns ordered list of goals to consider.
  """
  def prioritize_goals(state) do
    cond do
      # Critical: About to starve
      state.energy < starvation_threshold() ->
        [:emergency_food, :beg_for_food, :wander]

      # Urgent: Low energy
      state.energy < low_energy_threshold() ->
        [:find_food, :trade_for_food, :wander]

      # Economic: Low on gold
      state.inventory.gold < 5 ->
        [:seek_trade, :gather_resources, :wander]

      # Personality-driven goals
      state.personality == :greedy ->
        [:seek_trade, :gather_gold, :wander]

      state.personality == :social ->
        [:seek_goblin, :trade, :explore]

      state.personality == :cautious ->
        [:gather_resources, :avoid_crowds, :wander]

      # Default: Explore
      true ->
        [:wander, :seek_trade, :explore]
    end
  end

  # ->> RESOURCE RULES <<-

  @doc """
  Starting inventory for new goblins
  """
  def starting_inventory do
    %{
      gold: :rand.uniform(15) + 5,
      food: :rand.uniform(5) + 2,
      wood: :rand.uniform(3)
    }
  end

  @doc """
  Resource regeneration: how often resources respawn
  """
  def resource_respawn_rate, do: 50

  # ticks
end
