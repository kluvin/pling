defmodule PlingWeb.RoomLive do
  use PlingWeb, :live_view
  import PlingWeb.Components.PlaylistSelector
  alias Phoenix.LiveView.JS
  alias Pling.Rooms
  alias Pling.Rooms.Presence
  require Logger

  @impl true
  def mount(
        %{"room_code" => room_code, "game_mode" => game_mode} = params,
        %{"user_id" => user_id},
        socket
      ) do
    socket = init_assigns(socket, room_code, game_mode, user_id)

    if connected?(socket) do
      Logger.debug("LiveView connected for room: #{room_code}")

      {:ok, state} =
        case params do
          %{"playlist_id" => playlist_id} ->
            case Pling.Playlists.MusicLibrary.get_or_fetch_playlist(playlist_id) do
              {:ok, :first_track_saved, playlist} ->
                {:ok, state} = Rooms.join_room(room_code, user_id, self(), game_mode, playlist)
                Rooms.set_playlist(room_code, playlist_id)
                state

              {:ok, _, playlist} ->
                Rooms.join_room(room_code, user_id, self(), game_mode, playlist)

              {:error, reason} ->
                Logger.error("Failed to load playlist in UI: #{inspect(reason)}")
                Rooms.join_room(room_code, user_id, self(), game_mode)
            end

          _ ->
            Rooms.join_room(room_code, user_id, self(), game_mode)
        end

      {users, leader?} = Presence.initialize_presence(room_code, user_id)
      Phoenix.PubSub.subscribe(Pling.PubSub, "room:#{room_code}")

      {:ok,
       socket
       |> assign(users: users, leader?: leader?)
       |> assign(state)
       |> maybe_load_track(state.selection.track)}
    else
      Logger.debug("LiveView initial render for room: #{room_code}")
      {:ok, init_assigns(socket, room_code, game_mode, user_id)}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: ~p"/login")}
  end

  defp init_assigns(socket, room_code, game_mode, user_id) do
    assign(socket,
      room_code: room_code,
      user_id: user_id,
      show_playlist: false,
      game_mode: game_mode,
      current_track: nil,
      leader?: false,
      users: [],
      selection: %{playlist: nil, track: nil},
      playlists: nil,
      playing?: false,
      countdown: nil,
      timer_threshold: 10,
      scores: %{},
      recent_plings: []
    )
  end

  # ------------------------------------------------------------------
  # Presence diff
  # ------------------------------------------------------------------
  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {users, leader?} = Presence.update_presence(socket.assigns.room_code, socket.assigns.user_id)
    {:noreply, assign(socket, users: users, leader?: leader?)}
  end

  # ------------------------------------------------------------------
  # State and ephemeral(events(from(server)))
  # ------------------------------------------------------------------
  @impl true
  def handle_info(%{event: "state_update", payload: %{state: new_state}}, socket) do
    socket = assign(socket, new_state)
    {:noreply, maybe_load_track(socket, new_state.selection.track)}
  end

  @impl true
  def handle_info(%{event: "ring_bell"}, socket) do
    {:noreply, push_event(socket, "ring_bell", %{})}
  end

  @impl true
  def handle_info(%{event: "spotify:play"}, socket) do
    {:noreply, push_event(socket, "spotify:play", %{})}
  end

  @impl true
  def handle_info(%{event: "spotify:pause"}, socket) do
    {:noreply, push_event(socket, "spotify:pause", %{})}
  end

  # ------------------------------------------------------------------
  # UI Events -> Server Calls
  # ------------------------------------------------------------------
  @impl true
  def handle_event("counter:increment", %{"counter_id" => counter_id}, socket) do
    Rooms.update_score(socket.assigns.room_code, counter_id, 1)
    {:noreply, socket}
  end

  @impl true
  def handle_event("counter:decrement", %{"counter_id" => counter_id}, socket) do
    Rooms.update_score(socket.assigns.room_code, counter_id, -1)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_playlist_selector", _, socket) do
    {:noreply, assign(socket, show_playlist: !socket.assigns.show_playlist)}
  end

  @impl true
  def handle_event("set_playlist", %{"playlist_id" => playlist_id}, socket) do
    Rooms.set_playlist(socket.assigns.room_code, playlist_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_play", _params, %{assigns: %{leader?: false}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_play", _params, socket) do
    current_state = Rooms.get_state(socket.assigns.room_code)

    if current_state.playing? do
      Rooms.pause(socket.assigns.room_code)
    else
      Rooms.play(socket.assigns.room_code)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_track", _params, %{assigns: %{leader?: false}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_track", _params, socket) do
    Rooms.update_track(socket.assigns.room_code)
    {:noreply, socket}
  end

  # ------------------------------------------------------------------
  # Private Functions
  # ------------------------------------------------------------------
  defp maybe_load_track(%{assigns: %{leader?: true}} = socket, track) do
    if track != socket.assigns.current_track do
      socket
      |> assign(:current_track, track)
      |> push_event("spotify:load_track", %{track: track})
    else
      socket
    end
  end

  defp maybe_load_track(socket, _track), do: socket

  # ------------------------------------------------------------------
  # Components
  # ------------------------------------------------------------------
  def room_info(assigns) do
    ~H"""
    <div class="w-full text-center space-y-2">
      <div class="text-sm text-gray-500">{@room_code}</div>

      <.playlist_info selection={@selection} playlists={@playlists} />

      <div class="text-sm text-gray-500">
        <.user_list users={@users} user_id={@user_id} />
      </div>
    </div>
    """
  end

  defp playlist_info(%{selection: selection, playlists: playlists} = assigns)
       when not is_nil(selection) and not is_nil(playlists) do
    playlist_name =
      cond do
        # Get playlist name directly from the playlists map using playlist ID
        selection.playlist && Map.has_key?(playlists, selection.playlist) ->
          Map.get(playlists, selection.playlist).name

        # Get playlist name from track's playlist_spotify_id
        selection.track && Map.has_key?(playlists, selection.track.playlist_spotify_id) ->
          Map.get(playlists, selection.track.playlist_spotify_id).name

        true ->
          # Track exists but playlist not found, nothing.
          nil
          "Unknown Playlist"
      end

    assigns = assign(assigns, :playlist_name, playlist_name)

    ~H"""
    <div class="text-xs text-gray-400">
      <%= if @playlist_name do %>
        {@playlist_name}
      <% end %>
    </div>
    """
  end

  defp playlist_info(assigns), do: ~H""

  defp user_list(%{users: []} = assigns) do
    ~H"""
    {gettext("Waiting for users...")}
    """
  end

  defp user_list(%{users: [single_user], user_id: user_id} = assigns) do
    assigns =
      assigns
      |> assign(:is_current_user?, single_user.user_id == user_id)
      |> assign(:single_user, single_user)

    ~H"""
    <span class={if @is_current_user?, do: "font-bold"}>
      {@single_user.user_id}
    </span>
    {gettext("is here")}
    """
  end

  defp user_list(%{users: [first_user | other_users], user_id: user_id} = assigns) do
    other_users_with_current =
      Enum.map(other_users, fn user ->
        %{user: user, is_current?: user.user_id == user_id}
      end)

    assigns =
      assigns
      |> assign(:first_user, first_user)
      |> assign(:other_users_with_current, other_users_with_current)
      |> assign(:is_first_user?, first_user.user_id == user_id)

    ~H"""
    <span class={if @is_first_user?, do: "font-bold"}>
      {@first_user.user_id}
    </span>
    {gettext("is joined by")}
    <%= for {%{user: user, is_current?: is_current?}, index} <- Enum.with_index(@other_users_with_current) do %>
      <span class={if is_current?, do: "font-bold"}>
        {user.user_id}
      </span>
      {if index < length(@other_users_with_current) - 1, do: ", "}
    <% end %>
    """
  end

  def pling_button(assigns) do
    assigns = assign(assigns, :disabled?, !assigns.playing? && !assigns.leader?)

    ~H"""
    <div id="start" phx-hook="PlingButton" class="flex place-content-center w-full">
      <button class="pushable relative grid place-items-center" disabled={@disabled?}>
        <h1 class="inline absolute text-6xl z-50 font-bold text-center text-white drop-shadow-sm">
          <%= cond do %>
            <%!-- if we are counting down from <NUMBER> --%>
            <% @countdown && @countdown <= @timer_threshold -> %>
              {@countdown}
              <%!-- Otherwise, we are playing --%>
            <% @playing? -> %>
              {gettext("PLING")}
              <%!-- If we're not, leader will see Play --%>
            <% @leader? -> %>
              {gettext("PLAY")}
              <%!-- Everyone else gets Pling --%>
            <% true -> %>
              {gettext("PLING")}
          <% end %>
        </h1>
        <audio id="bell">
          <source src={~p"/audio/bell.mp3"} type="audio/mp3" />
        </audio>
        <span class={"edge #{if @disabled?, do: "bg-gray-800", else: "bg-red-800"}"}></span>
        <span class={"front #{if @disabled?, do: "bg-gradient-to-b from-gray-500 to-gray-600", else: "bg-gradient-to-b from-red-500 to-red-600"}"}>
        </span>
      </button>
    </div>
    """
  end

  def render_scores(assigns) do
    ~H"""
    <div class="col-span-3 flex flex-col space-y-4 w-full px-4">
      <div class="flex justify-between items-center">
        <div class="text-lg font-semibold">{gettext("Scores")}</div>
        <%= if @leader? && length(@recent_plings) > 0 do %>
          <.button phx-click="clear_plings">
            {gettext("Clear Recent")}
          </.button>
        <% end %>
      </div>

      <div class="space-y-2">
        <%= for user <- @users do %>
          <div class={"ring flex justify-between items-center p-2 rounded #{if user.user_id in @recent_plings, do: "bg-yellow-100 animate-pulse", else: "bg-slate-50"}"}>
            <span class={"font-medium #{if user.user_id == @user_id, do: "font-bold"}"}>
              {user.user_id}
            </span>
            <div class="flex items-center space-x-2">
              <span class="text-lg font-bold">
                {Map.get(@scores, user.user_id, 0)}
              </span>
              <%= if @leader? do %>
                <div class="flex space-x-1">
                  <.button phx-click="counter:decrement" phx-value-counter_id={user.user_id}>
                    -1
                  </.button>
                  <.button phx-click="counter:increment" phx-value-counter_id={user.user_id}>
                    +1
                  </.button>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp counter_button(assigns) do
    {edge_class, bg_class} =
      case assigns.counter_id do
        "blue" -> {"bg-blue-800", "bg-gradient-to-b from-blue-500 to-blue-600"}
        "red" -> {"bg-red-800", "bg-gradient-to-b from-red-500 to-red-600"}
        _ -> {"bg-gray-800", "bg-gradient-to-b from-gray-500 to-gray-600"}
      end

    count_value = Map.get(assigns.scores || %{}, assigns.counter_id, 0)

    assigns =
      assign(assigns,
        edge_class: edge_class,
        bg_class: bg_class,
        count: count_value
      )

    ~H"""
    <div class="relative flex flex-col items-center gap-4">
      <button
        id={"#{@counter_id}-counter-incr"}
        phx-click={JS.push("counter:increment", value: %{counter_id: @counter_id})}
        class="pushable"
      >
        <span class="shadow"></span>
        <span class={["edge", @edge_class]}></span>
        <span class={[
          "front !flex !items-center justify-center !text-2xl !font-semibold !p-0 !w-24 !h-24",
          @bg_class
        ]}>
          {@count}
        </span>
      </button>
      <button
        phx-click={JS.push("counter:decrement", value: %{counter_id: @counter_id})}
        id={"#{@counter_id}-counter-decr"}
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

  defp playlist_grid(%{selection: selection, playlists: playlists} = assigns) do
    playlists_with_active =
      if playlists do
        Enum.map(playlists, fn {_id, playlist} ->
          Map.put(playlist, :active?, selection.playlist == playlist.spotify_id)
        end)
      else
        []
      end

    assigns = assign(assigns, :playlists_with_active, playlists_with_active)

    ~H"""
    <div class="col-span-3 grid grid-cols-3 place-items-center gap-4 rounded w-full">
      <%= for playlist <- @playlists_with_active do %>
        <.playlist id={playlist.spotify_id} name={playlist.name} active?={playlist.active?} />
      <% end %>
    </div>
    """
  end
end
