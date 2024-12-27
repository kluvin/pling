defmodule Pling.Rooms.Presence do
  @moduledoc """
  Handles user presence and leadership election in rooms.
  """

  alias Pling.PresenceTracker
  require Logger

  @doc """
  Determines if the given user is the leader in the room.
  The leader is the first user in the list of users.
  """
  def elect_leader(users, user_id) when is_list(users) do
    case users do
      [%{user_id: first_user_id} | _] -> first_user_id == user_id
      _ -> false
    end
  end

  @doc """
  Initializes room presence by tracking the user and subscribing to the topic.
  """
  def initialize_presence(room_code, user_id) do
    topic = PresenceTracker.topic(room_code)

    PresenceTracker.track(room_code, user_id)
    PlingWeb.Endpoint.subscribe(topic)

    users = PresenceTracker.list_users(room_code)
    is_leader = elect_leader(users, user_id)

    {users, is_leader}
  end

  @doc """
  Updates room presence for a user and returns the current users list and leader status.
  """
  def update_presence(room_code, user_id) do
    users = PresenceTracker.list_users(room_code)
    is_leader = elect_leader(users, user_id)

    if Enum.empty?(users) do
      Pling.Rooms.RoomManagement.terminate_room(room_code)
    end

    {users, is_leader}
  end
end
