defmodule PlingWeb.PresenceChannel do
  use Phoenix.Channel
  alias Pling.Presence

  def join("room:" <> room_code, _params, socket) do
    {:ok, assign(socket, :room_code, room_code)}
  end

  def handle_in("track_user", %{"user_id" => user_id}, socket) do
    Presence.track(socket.assigns.room_code, user_id)

    broadcast_from!(socket, "presence_diff", %{
      users: Presence.list_users(socket.assigns.room_code)
    })

    {:noreply, socket}
  end
end
