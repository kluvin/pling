defmodule PlingWeb.HomeLive do
  use PlingWeb, :live_view
  require Logger
  alias Pling.Services.NamesService

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_rules_modal: false)}
  end

  @impl true
  def handle_event("create_room", %{"game_mode" => game_mode}, socket) do
    room_code = generate_room_code()
    {:noreply, push_navigate(socket, to: ~p"/#{game_mode}/#{room_code}")}
  end

  @impl true
  def handle_event("join_room", %{"room_code" => room_code}, socket) do
    upper_room_code = String.upcase(room_code)
    Logger.info("Joining room: #{upper_room_code}")
    {:noreply, push_navigate(socket, to: ~p"/vs/#{upper_room_code}")}
  end

  defp generate_room_code do
    noun1 = NamesService.random_noun()
    noun2 = NamesService.random_noun()

    (noun1 <> noun2)
    |> String.upcase()
  end
end
