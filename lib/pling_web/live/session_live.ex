defmodule PlingWeb.SessionLive do
  use PlingWeb, :live_view
  import PlingWeb.Components.PlaylistSelector
  alias Pling.Playlists
  alias Phoenix.LiveView.JS
  alias PlingWeb.Presence
  require Logger

  # Add room-specific topic
  def topic(room_code), do: "pling:room:#{room_code}"

  @initial_state %{
    red_count: 0,
    blue_count: 0,
    is_playing: false,
    countdown: nil,
    timer_threshold: 10,
    spotify_timeout: 30,
    default_decade: "90s"
  }

  @impl true
  def mount(%{"room_code" => room_code}, %{"user_id" => user_id}, socket) do
    if connected?(socket) do
      topic = topic(room_code)

      # Track user in this specific room
      Presence.track(self(), topic, user_id, %{
        user_id: user_id,
        joined_at: DateTime.utc_now()
      })

      # Subscribe to room-specific updates
      PlingWeb.Endpoint.subscribe(topic)
    end

    playlists = Playlists.load_playlists()

    track =
      playlists |> Playlists.get_tracks(@initial_state.default_decade) |> Playlists.random_track()

    {:ok,
     socket
     |> assign(:room_code, room_code)
     |> assign(:user_id, user_id)
     |> assign(:users, list_room_users(room_code))
     |> assign(:playlists, playlists)
     |> assign(:selection, %{playlist: @initial_state.default_decade, track: track})
     |> assign(@initial_state)}
  end

  # Fallback mount for unauthenticated users
  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/login")}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :users, list_room_users(socket.assigns.room_code))}
  end

  @impl true
  def handle_event("set_playlist", %{"decade" => decade}, socket) do
    Logger.info("Changing playlist to #{decade}")

    socket =
      socket
      |> set_selection(decade)
      |> reset_playback()

    {:noreply, socket}
  end

  def handle_event("next_track", _params, socket) do
    Logger.info("Loading next track for playlist #{socket.assigns.selection.playlist}")
    {:noreply, set_selection(socket, socket.assigns.selection.playlist)}
  end

  def handle_event("increment_counter", %{"color" => color}, socket) do
    counter_key = String.to_atom("#{color}_count")
    new_count = socket.assigns[counter_key] + 1
    Logger.info("Incrementing #{color} counter to #{new_count}")

    socket =
      socket
      |> update(counter_key, &(&1 + 1))
      |> reset_playback()

    {:noreply, socket}
  end

  def handle_event("decrement_counter", %{"color" => color}, socket) do
    counter_key = String.to_atom("#{color}_count")
    # Prevent negative counts
    new_count = max(0, socket.assigns[counter_key] - 1)
    Logger.info("Decrementing #{color} counter to #{new_count}")

    {:noreply, update(socket, counter_key, &max(0, &1 - 1))}
  end

  def handle_event("toggle_play", _params, %{assigns: %{is_playing: false}} = socket) do
    Logger.info("Toggle play: starting playback")

    socket =
      socket
      |> start_playback()

    Process.send_after(self(), :tick, 1000)
    {:noreply, socket}
  end

  def handle_event("toggle_play", _params, %{assigns: %{is_playing: true}} = socket) do
    Logger.info("Stopping playback")

    socket =
      socket
      |> reset_playback()
      |> push_event("ring_bell", %{})
      |> push_event("spotify_toggle", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :users, list_room_users(socket.assigns.room_code))}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{countdown: nil}} = socket), do: {:noreply, socket}

  @impl true
  def handle_info(:tick, %{assigns: %{countdown: 0}} = socket) do
    Logger.info("Timeout")

    socket =
      socket
      |> push_event("ring_bell", %{})
      |> set_selection(socket.assigns.selection.playlist)
      |> start_playback()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{countdown: countdown}} = socket) do
    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, :countdown, countdown - 1)}
  end

  defp reset_playback(socket) do
    Logger.info("Reset playback")

    socket
    |> assign(:is_playing, false)
    |> assign(:countdown, nil)
    |> push_event("spotify_toggle", %{})
  end

  defp start_playback(socket) do
    Logger.info("Start playback")

    socket
    |> set_selection(socket.assigns.selection.playlist)
    |> assign(:is_playing, true)
    |> assign(:countdown, socket.assigns.spotify_timeout)
    |> push_event("spotify_toggle", %{})
  end

  defp set_selection(socket, playlist) do
    track =
      socket.assigns.playlists
      |> Playlists.get_tracks(playlist)
      |> Playlists.random_track()

    socket
    |> assign(:selection, %{playlist: playlist, track: track})
    |> push_event("update_track", %{track: track})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div title="Pling">
      <main class="subpixel-antialiased mx-12 select-none">
        <div class="h-full sticky">
          <div class="w-full mt-8 space-y-8 flex flex-col place-items-center">
            <.room_info room_code={@room_code} users={@users} />
            <.pling_button countdown={@countdown} timer_threshold={@timer_threshold} />
            <.counters red_count={@red_count} blue_count={@blue_count} />
            <.playlist_grid selection={@selection} />
          </div>
        </div>
        <.embed_wrapper />
      </main>
    </div>
    """
  end

  def room_info(assigns) do
    ~H"""
    <div class="w-full text-center space-y-2">
      <div class="text-sm text-gray-500"><%= @room_code %></div>
      <div class="text-sm text-gray-500">
        <%= length(@users) %> <%= if length(@users) == 1, do: "person", else: "people" %> here
      </div>
    </div>
    """
  end

  def pling_button(assigns) do
    ~H"""
    <div id="start" class="flex place-content-center w-screen px-12" phx-click="toggle_play">
      <button id="pling-button" class="pushable relative grid place-items-center">
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
        phx-click={JS.push("decrement_counter", value: %{color: @color})}
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

  defp embed_wrapper(assigns) do
    ~H"""
    <div class="embed-wrapper z-10 pb-2 sticky w-full">
      <div id="embed-iframe" style="display: none; height: 0; width: 0; position: absolute;"></div>
    </div>
    """
  end

  defp list_room_users(room_code) do
    topic(room_code)
    |> Presence.list()
    |> Enum.map(fn {_user_id, data} -> hd(data.metas) end)
  end
end
