defmodule Pling.Rooms.Presence do
  @moduledoc """
  Handles user presence and leadership election in rooms.
  """

  alias Pling.{Presence, Rooms}

  @doc """
  Determines if the given user is the leader in the room.
  """
  def elect_leader(user_id, current_state) do
    current_state.leader_id == user_id
  end

  @doc """
  Initializes room presence by tracking the user and subscribing to the topic.
  """
  def initialize_presence(room_code, user_id) do
    topic = Presence.topic(room_code)

    Presence.track(room_code, user_id)
    PlingWeb.Endpoint.subscribe(topic)

    users = Presence.list_users(room_code)
    current_state = Rooms.get_state(room_code)
    leader? = elect_leader(user_id, current_state)

    {users, leader?}
  end

  @doc """
  Updates room presence for a user and returns the current users list and leader status.
  """
  def update_presence(room_code, user_id) do
    users = Presence.list_users(room_code)
    current_state = Rooms.get_state(room_code)
    leader? = elect_leader(user_id, current_state)

    if Enum.empty?(users) do
      Pling.Rooms.Room.Impl.terminate_room(room_code)
    end

    {users, leader?}
  end
end
