defmodule PlingWeb.HomeLive do
  use PlingWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_join_modal: false)}
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    room_code = generate_room_code()
    {:noreply, push_navigate(socket, to: ~p"/r/#{room_code}")}
  end

  @impl true
  def handle_event("show_join_modal", _params, socket) do
    {:noreply, assign(socket, show_join_modal: true)}
  end

  @impl true
  def handle_event("hide_join_modal", _params, socket) do
    {:noreply, assign(socket, show_join_modal: false)}
  end

  @impl true
  def handle_event("join_room", %{"room_code" => room_code}, socket) do
    upper_room_code = String.upcase(room_code)
    Logger.info("Joining room: #{upper_room_code}")
    {:noreply, push_navigate(socket, to: ~p"/r/#{upper_room_code}")}
  end

  defp generate_room_code do
    :crypto.strong_rand_bytes(3)
    |> Base.encode32(padding: false)
    |> String.slice(0, 4)
    |> String.upcase()
  end
end
