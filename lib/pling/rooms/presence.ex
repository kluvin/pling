defmodule Pling.Rooms.Presence do
  @moduledoc """
  Handles user presence and leadership election in rooms.
  """

  alias Pling.{PresenceTracker, Rooms}
  require Logger

  @doc """
  Determines if the given user is the leader in the room.
  """
  def elect_leader(user_id, current_state) do
    Logger.info("Electing leader",
      user_id: user_id,
      current_leader: current_state.leader_id,
      leader?: current_state.leader_id == user_id
    )

    current_state.leader_id == user_id
  end

  @doc """
  Initializes room presence by tracking the user and subscribing to the topic.
  """
  def initialize_presence(room_code, user_id) do
    topic = PresenceTracker.topic(room_code)

    PresenceTracker.track(room_code, user_id)
    PlingWeb.Endpoint.subscribe(topic)

    users = PresenceTracker.list_users(room_code)
    current_state = Rooms.get_state(room_code)
    leader? = elect_leader(user_id, current_state)

    {users, leader?}
  end

  @doc """
  Updates room presence for a user and returns the current users list and leader status.
  """
  def update_presence(room_code, user_id) do
    users = PresenceTracker.list_users(room_code)
    current_state = Rooms.get_state(room_code)
    leader? = elect_leader(user_id, current_state)

    if Enum.empty?(users) do
      Pling.Rooms.RoomManagement.terminate_room(room_code)
    end

    {users, leader?}
  end
end
