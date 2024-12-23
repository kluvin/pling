defmodule PlingWeb.SessionLive do
  use PlingWeb, :live_view
  import PlingWeb.Components.PlaylistSelector
  alias Phoenix.LiveView.JS
  alias PlingWeb.Presence
  require Logger

  def topic(room_code), do: "pling:room:#{room_code}"

  @impl true
  def mount(%{"room_code" => room_code}, %{"user_id" => user_id}, socket) do
    Logger.metadata(room_code: room_code, user_id: user_id)
    Logger.info("User joining room", event: :room_join)

    if connected?(socket) do
      topic = topic(room_code)

      DynamicSupervisor.start_child(Pling.RoomSupervisor, {Pling.PlingServer, room_code})
      Logger.info("Started PlingServer", event: :server_start)

      Presence.track(self(), topic, user_id, %{
        user_id: user_id,
        joined_at: DateTime.utc_now()
      })

      PlingWeb.Endpoint.subscribe(topic)
    end

    current_state = Pling.PlingServer.get_state(room_code)

    socket =
      socket
      |> assign(:room_code, room_code)
      |> assign(:user_id, user_id)
      |> assign(:users, list_room_users(room_code))
      |> assign(current_state)
      |> then(fn socket ->
        if connected?(socket) and current_state.selection.track do
          push_event(socket, "update_track", %{track: current_state.selection.track})
        else
          socket
        end
      end)

    {:ok, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/login")}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    users = list_room_users(socket.assigns.room_code)
    Logger.info("Presence update", event: :presence_change, user_count: length(users))

    if users == [] do
      Logger.info("Room empty, resetting state", event: :room_reset)
      Pling.PlingServer.reset_state(socket.assigns.room_code)
    end

    {:noreply, assign(socket, :users, users)}
  end

  @impl true
  def handle_info(%{event: "state_update", payload: %{state: state}}, socket) do
    {:noreply, assign(socket, state)}
  end

  @impl true
  def handle_info(%{event: "tick", payload: %{countdown: countdown}}, socket) do
    {:noreply, assign(socket, :countdown, countdown)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "spotify_play"}, socket) do
    {:noreply, push_event(socket, "spotify_play", %{})}
  end

  defp update_state_and_broadcast(socket, new_state) do
    broadcast_state_update(socket.assigns.room_code, new_state)
    assign(socket, new_state)
  end

  defp push_client_events(socket, events) do
    Enum.reduce(events, socket, fn
      {:update_track, track}, acc -> push_event(acc, "update_track", %{track: track})
      {:spotify_play}, acc -> push_event(acc, "spotify_play", %{})
      {:spotify_pause}, acc -> push_event(acc, "spotify_pause", %{})
      :ring_bell, acc -> push_event(acc, "ring_bell", %{})
      _, acc -> acc
    end)
  end

  defp update_state_and_socket(socket, new_state, extra_events \\ []) do
    socket
    |> update_state_and_broadcast(new_state)
    |> push_client_events(extra_events)
  end

  def handle_event("increment_counter", %{"color" => color}, socket) do
    Logger.info("Counter increment", event: :counter_increment, color: color)
    new_state = Pling.PlingServer.increment_counter(socket.assigns.room_code, color)
    {:noreply, update_state_and_socket(socket, new_state)}
  end

  def handle_event("decrement_counter", %{"color" => color}, socket) do
    Logger.info("Counter decrement", event: :counter_decrement, color: color)
    new_state = Pling.PlingServer.decrement_counter(socket.assigns.room_code, color)
    {:noreply, update_state_and_socket(socket, new_state)}
  end

  def handle_event("set_playlist", %{"decade" => decade}, socket) do
    Logger.info("Playlist change", event: :playlist_change, decade: decade)
    new_state = Pling.PlingServer.set_playlist(socket.assigns.room_code, decade)

    {:noreply,
     update_state_and_socket(socket, new_state, [
       {:update_track, new_state.selection.track},
       :spotify_toggle
     ])}
  end

  def handle_event("toggle_play", _params, socket) do
    current_state = Pling.PlingServer.get_state(socket.assigns.room_code)

    {new_state, extra_events} =
      if current_state.is_playing do
        Logger.info("Stopping playback", event: :playback_stop)

        {Pling.PlingServer.stop_playback(socket.assigns.room_code),
         [{:spotify_pause}, :ring_bell]}
      else
        Logger.info("Starting playback", event: :playback_start)
        {Pling.PlingServer.start_playback(socket.assigns.room_code), [{:spotify_play}]}
      end

    {:noreply, update_state_and_socket(socket, new_state, extra_events)}
  end

  @impl true
  def handle_event("next_track", _params, socket) do
    Logger.info("Advancing to next track", event: :next_track)
    new_state = Pling.PlingServer.next_track(socket.assigns.room_code)

    {:noreply,
     update_state_and_socket(socket, new_state, [{:update_track, new_state.selection.track}])}
  end

  def handle_event("load_new_track", _params, socket) do
    new_state = Pling.PlingServer.next_track(socket.assigns.room_code)

    {:noreply,
     update_state_and_socket(socket, new_state, [{:update_track, new_state.selection.track}])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full mt-8 space-y-8 flex flex-col place-items-center">
      <.room_info room_code={@room_code} users={@users} />
      <.pling_button countdown={@countdown} timer_threshold={@timer_threshold} />
      <.counters red_count={@red_count} blue_count={@blue_count} />
      <.playlist_grid selection={@selection} />
    </div>
    """
  end

  def room_info(assigns) do
    ~H"""
    <div class="w-full text-center space-y-2">
      <div class="text-sm text-gray-500"><%= @room_code %></div>
      <div class="text-sm text-gray-500">
        <%= if length(@users) == 1 do %>
          <%= Enum.at(@users, 0).user_id %> is here
        <% else %>
          <%= Enum.at(@users, 0).user_id %> is joined by <%= Enum.slice(@users, 1..-1)
          |> Enum.map(& &1.user_id)
          |> Enum.join(", ") %>
        <% end %>
      </div>
    </div>
    """
  end

  def pling_button(assigns) do
    ~H"""
    <div id="start" phx-hook="PlingButton" class="flex place-content-center w-screen px-12">
      <button class="pushable relative grid place-items-center">
        <h1 class="inline absolute text-6xl z-50 font-bold text-center text-white drop-shadow-sm">
          <%= if @countdown && @countdown <= @timer_threshold, do: @countdown, else: "PLING" %>
        </h1>
        <audio id="bell">
          <source src={~p"/audio/bell.mp3"} type="audio/mp3" />
        </audio>
        <span class="edge bg-red-800"></span>
        <span class="front bg-gradient-to-b from-red-500 to-red-600"></span>
      </button>
    </div>
    """
  end

  defp counters(assigns) do
    ~H"""
    <div class="flex w-full justify-between">
      <.counter_button color="red" red_count={@red_count} blue_count={@blue_count} />
      <.counter_button color="blue" red_count={@red_count} blue_count={@blue_count} />
    </div>
    """
  end

  defp counter_button(assigns) do
    {edge_class, bg_class} =
      case assigns.color do
        "blue" -> {"bg-blue-800", "bg-gradient-to-b from-blue-500 to-blue-600"}
        "red" -> {"bg-red-800", "bg-gradient-to-b from-red-500 to-red-600"}
        _ -> {"bg-gray-800", "bg-gradient-to-b from-gray-500 to-gray-600"}
      end

    count_value = if assigns.color == "red", do: assigns.red_count, else: assigns.blue_count

    assigns =
      assign(assigns,
        edge_class: edge_class,
        bg_class: bg_class,
        count: count_value
      )

    ~H"""
    <div class="relative flex flex-col items-center gap-4">
      <button
        id={"#{@color}-counter-incr"}
        phx-hook="PlingCounter"
        phx-click={
          JS.push("increment_counter", value: %{color: @color})
          |> JS.push("next_track")
        }
        class="pushable"
      >
        <span class="shadow"></span>
        <span class={["edge", @edge_class]}></span>
        <span class={[
          "front !flex !items-center justify-center !text-2xl !font-semibold !p-0 !w-24 !h-24",
          @bg_class
        ]}>
          <%= @count %>
        </span>
      </button>
      <button
        phx-hook="PlingCounter"
        phx-click={JS.push("decrement_counter", value: %{color: @color})}
        id={"#{@color}-counter-decr"}
        class="pushable self-center"
      >
        <span class="shadow"></span>
        <span class={["edge", @edge_class]}></span>
        <span class={[
          "front !flex !items-center justify-center !text-xl !font-semibold !p-0 !w-12 !h-12",
          @bg_class
        ]}>
          -
        </span>
      </button>
    </div>
    """
  end

  defp playlist_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-3 place-items-center gap-4 rounded w-full">
      <.playlist decade="50s" active?={@selection.playlist == "50s"} />
      <.playlist decade="60s" active?={@selection.playlist == "60s"} />
      <.playlist decade="70s" active?={@selection.playlist == "70s"} />
      <.playlist decade="80s" active?={@selection.playlist == "80s"} />
      <.playlist decade="90s" active?={@selection.playlist == "90s"} />
      <.playlist decade="mix" active?={@selection.playlist == "mix"} />
    </div>
    """
  end

  defp list_room_users(room_code) do
    presence_data = topic(room_code) |> Presence.list()
    user_count = map_size(presence_data)
    Logger.info("Room users listed", event: :list_users, user_count: user_count)

    presence_data
    |> Map.keys()
    |> Enum.map(fn user_id ->
      %{user_id: user_id, joined_at: DateTime.utc_now()}
    end)
  end

  defp broadcast_state_update(room_code, state) do
    Logger.info("Broadcasting state update", event: :state_broadcast)
    PlingWeb.Endpoint.broadcast(topic(room_code), "state_update", %{state: state})
  end
end
