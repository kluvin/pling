defmodule Pling.Rooms.FreeForAll do
  @moduledoc """
  Handles Free-for-All game mode operations like scoring and pling management.
  """

  @doc """
  Increments a player's score by the given amount.
  """
  def increment_score(state, user_id, amount \\ 1) do
    current_score = Map.get(state.player_scores, user_id, 0)
    %{state | player_scores: Map.put(state.player_scores, user_id, current_score + amount)}
  end

  @doc """
  Decrements a player's score by the given amount, ensuring it doesn't go below 0.
  """
  def decrement_score(state, user_id, amount \\ 1) do
    current_score = Map.get(state.player_scores, user_id, 0)

    %{
      state
      | player_scores: Map.put(state.player_scores, user_id, max(0, current_score - amount))
    }
  end

  @doc """
  Adds a user to the recent plings list.
  """
  def add_pling(state, user_id) do
    %{state | recent_plings: [user_id | state.recent_plings]}
  end

  @doc """
  Clears all recent plings.
  """
  def clear_plings(state) do
    %{state | recent_plings: []}
  end
end
