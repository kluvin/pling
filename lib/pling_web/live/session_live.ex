defmodule PlingWeb.SessionLive do
  use PlingWeb, :live_view
  import PlingWeb.Components.PlaylistSelector
  alias Phoenix.LiveView.JS
  alias PlingWeb.Presence
  alias Pling.PlingServer
  require Logger

  def topic(room_code), do: "pling:room:#{room_code}"

  @impl true
  def mount(%{"room_code" => room_code}, %{"user_id" => user_id}, socket) do
    Logger.metadata(room_code: room_code, user_id: user_id)
    Logger.info("User joining room", event: :room_join)

    if connected?(socket) do
      topic = topic(room_code)

      server_pid =
        Pling.PlingServerRegistry
        |> Registry.lookup(room_code)
        |> case do
          [{pid, _}] -> pid
          [] -> start_room_server(room_code)
        end

      send(server_pid, {:monitor_liveview, self()})

      Presence.track(self(), topic, user_id, %{
        user_id: user_id,
        joined_at: DateTime.utc_now()
      })

      PlingWeb.Endpoint.subscribe(topic)
    end

    current_state = Pling.PlingServer.get_state(room_code)
    users = list_room_users(room_code)

    first_user_leader_election =
      case users do
        [%{user_id: first_user_id} | _] -> first_user_id == user_id
        _ -> true
      end

    socket =
      socket
      |> assign(:room_code, room_code)
      |> assign(:user_id, user_id)
      |> assign(:users, users)
      |> assign(:is_leader, first_user_leader_election)
      |> assign(current_state)

    {:ok, push_event(socket, "spotify:load_track", %{track: current_state.selection.track})}
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/login")}
  end

  # ------------------------------------------------------------------
  # Presence diff
  # ------------------------------------------------------------------
  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    users = list_room_users(socket.assigns.room_code)

    first_user_leader_election =
      case users do
        [%{user_id: first_user_id} | _] -> first_user_id == socket.assigns.user_id
        _ -> false
      end

    if users == [] do
      case Registry.lookup(Pling.PlingServerRegistry, socket.assigns.room_code) do
        [{pid, _}] ->
          DynamicSupervisor.terminate_child(Pling.RoomSupervisor, pid)
          Logger.info("Room empty, server terminated", event: :room_terminate)

        [] ->
          Logger.info("Room empty but server not found", event: :room_terminate)
      end
    end

    {:noreply, assign(socket, users: users, is_leader: first_user_leader_election)}
  end

  # ------------------------------------------------------------------
  # State and ephemeral events from server
  # ------------------------------------------------------------------
  @impl true
  def handle_info(%{event: "state_update", payload: %{state: state}}, socket) do
    {:noreply, assign(socket, state)}
  end

  @impl true
  def handle_info(%{event: "tick", payload: %{countdown: countdown}}, socket) do
    {:noreply, assign(socket, :countdown, countdown)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "spotify:play_track", payload: %{track: track}},
        socket
      ) do
    {:noreply, push_event(socket, "spotify:play_track", %{track: track})}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "ring_bell"}, socket) do
    {:noreply, push_event(socket, "ring_bell", %{})}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "spotify:load_track", payload: %{track: track}},
        socket
      ) do
    {:noreply, push_event(socket, "spotify:load_track", %{track: track})}
  end

  # ------------------------------------------------------------------
  # UI Events -> Server Calls
  # ------------------------------------------------------------------
  @impl true
  def handle_event("counter:increment", %{"color" => color}, socket) do
    Logger.info("Counter increment", event: :counter_increment, color: color)
    Pling.PlingServer.counter(:increment, socket.assigns.room_code, color)
    {:noreply, socket}
  end

  def handle_event("counter:decrement", %{"color" => color}, socket) do
    Logger.info("Counter decrement", event: :counter_decrement, color: color)
    Pling.PlingServer.counter(:decrement, socket.assigns.room_code, color)
    {:noreply, socket}
  end

  def handle_event("set_playlist", %{"decade" => decade}, socket) do
    Logger.info("Playlist change", event: :playlist_change, decade: decade)
    Pling.PlingServer.set_playlist(socket.assigns.room_code, decade)
    {:noreply, socket}
  end

  def handle_event("toggle_play", _params, socket) do
    current_state = Pling.PlingServer.get_state(socket.assigns.room_code)

    if current_state.is_playing do
      Logger.info("Stopping playback", event: :playback_stop)
      Pling.PlingServer.stop_playback(socket.assigns.room_code)
    else
      Logger.info("Starting playback", event: :playback_start)
      Pling.PlingServer.start_playback(socket.assigns.room_code)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_track", _params, socket) do
    Logger.info("Advancing to next track", event: :next_track)
    Pling.PlingServer.next_track(socket.assigns.room_code)
    {:noreply, socket}
  end

  def handle_event("load_new_track", _params, socket) do
    Pling.PlingServer.next_track(socket.assigns.room_code)
    {:noreply, socket}
  end

  # ------------------------------------------------------------------
  # Render
  # ------------------------------------------------------------------
  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    Logger.debug(Map.take(assigns, [:selection, :countdown, :is_playing, :__changed__]),
      pretty: true
    )

    ~H"""
    <%!-- todo, enable me in dev mode --%>
    <%!-- <pre class="w-1/2"><%= inspect(Map.take(assigns, [:selection, :countdown, :is_playing, :__changed__]), pretty: true) %></pre> --%>
    <div class="w-full mt-8 space-y-8 flex flex-col place-items-center">
      <.room_info room_code={@room_code} users={@users} />
      <.pling_button
        is_playing={@is_playing}
        countdown={@countdown}
        timer_threshold={@timer_threshold}
      />
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
          <%= Enum.at(@users, 0).user_id %> is joined by <%= @users
          |> Enum.drop(1)
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
          <%= cond do %>
            <% @countdown && @countdown <= @timer_threshold -> %>
              <%= @countdown %>
            <% @is_playing -> %>
              PLING
            <% true -> %>
              PLAY
          <% end %>
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
        phx-click={JS.push("counter:increment", value: %{color: @color})}
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
        phx-click={JS.push("counter:decrement", value: %{color: @color})}
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
    topic(room_code)
    |> Presence.list()
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      %{user_id: user_id, joined_at: meta.joined_at}
    end)
    |> Enum.sort_by(& &1.joined_at)
  end

  # Helper function to start a new room server
  defp start_room_server(room_code) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Pling.RoomSupervisor,
        {PlingServer, room_code}
      )

    pid
  end
end
