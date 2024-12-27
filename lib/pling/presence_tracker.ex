defmodule Pling.PresenceTracker do
  @moduledoc """
  Handles presence tracking for room participants through Phoenix.Presence.
  """
  alias Pling.Presence

  def topic(room_code), do: "pling:room:#{room_code}"

  @doc """
  Tracks a user's presence in a room.
  """
  def track(room_code, user_id) do
    Presence.track(self(), topic(room_code), user_id, %{
      user_id: user_id,
      joined_at: DateTime.utc_now()
    })
  end

  @doc """
  Lists all users in a room, sorted by join time.
  """
  def list_users(room_code) do
    topic(room_code)
    |> Presence.list()
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      %{user_id: user_id, joined_at: meta.joined_at}
    end)
    |> Enum.sort_by(& &1.joined_at)
  end
end
