defmodule Pling.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  This module combines the core Phoenix.Presence functionality with room-specific
  presence tracking capabilities.
  """
  use Phoenix.Presence,
    otp_app: :pling,
    pubsub_server: Pling.PubSub

  def topic(room_code), do: "room:#{room_code}"

  @doc """
  Tracks a user's presence in a room.
  """
  def track(room_code, user_id) do
    track(self(), topic(room_code), user_id, %{
      user_id: user_id,
      joined_at: DateTime.utc_now()
    })
  end

  @doc """
  Lists all users in a room, sorted by join time.
  """
  def list_users(room_code) do
    topic(room_code)
    |> list()
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      %{user_id: user_id, joined_at: meta.joined_at}
    end)
    |> Enum.sort_by(& &1.joined_at)
  end
end
