defmodule PlingWeb.RoomLive do
  use PlingWeb, :live_view
  import PlingWeb.Components.PlaylistSelector
  alias Phoenix.LiveView.JS
  alias Pling.Rooms
  alias Pling.Rooms.Presence
  require Logger

  @impl true
  def mount(
        %{"room_code" => room_code, "game_mode" => game_mode},
        %{"user_id" => user_id},
        socket
      ) do
    socket =
      assign(socket,
        room_code: room_code,
        user_id: user_id,
        show_playlist: false,
        game_mode: game_mode
      )

    if connected?(socket) do
      {:ok, state} = Rooms.join_room(room_code, user_id, self(), game_mode)

      Phoenix.PubSub.subscribe(Pling.PubSub, "room:#{room_code}")

      {:ok,
       socket
       |> assign(state)
       |> push_event("spotify:load_track", %{track: state.selection.track})}
    else
      {:ok, assign(socket, Rooms.get_state(room_code))}
    end
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
    {users, leader?} = Presence.update_presence(socket.assigns.room_code, socket.assigns.user_id)
    {:noreply, assign(socket, users: users, leader?: leader?)}
  end

  # ------------------------------------------------------------------
  # State and ephemeral(events(from(server)))
  # ------------------------------------------------------------------
  @impl true
  def handle_info(%{event: "state_update", payload: %{state: new_state}}, socket) do
    {:noreply,
     assign(
       socket,
       Map.take(new_state, [:playing?, :countdown, :selection, :scores, :recent_plings])
     )}
  end

  @impl true
  def handle_info(
        %{event: "score_update", payload: %{identifier: identifier, score: score}},
        socket
      ) do
    Logger.info("LiveView received score update",
      room_code: socket.assigns.room_code,
      identifier: identifier,
      score: score
    )

    {:noreply, update(socket, :scores, &Map.put(&1, identifier, score))}
  end

  @impl true
  def handle_info(%{event: "countdown_update", payload: %{countdown: countdown}}, socket) do
    {:noreply, assign(socket, :countdown, countdown)}
  end

  @impl true
  def handle_info(:tick, socket) do
    Rooms.process_tick(socket.assigns.room_code)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "ring_bell"}, socket) do
    {:noreply, push_event(socket, "ring_bell", %{})}
  end

  @impl true
  def handle_info(
        %{event: "spotify:load_track", payload: %{track: track}},
        %{assigns: %{leader?: true}} = socket
      ) do
    {:noreply, push_event(socket, "spotify:load_track", %{track: track})}
  end

  @impl true
  def handle_info(%{event: "spotify:load_track"}, socket) do
    # right now, only leader is getting a new track
    # since no one else is meant to play audio
    {:noreply, socket}
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
  def handle_event("counter:increment", %{"color" => color}, socket) do
    Rooms.update_score(socket.assigns.room_code, color, 1)
    {:noreply, socket}
  end

  @impl true
  def handle_event("counter:decrement", %{"color" => color}, socket) do
    Rooms.update_score(socket.assigns.room_code, color, -1)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_playlist_selector", _params, socket) do
    {:noreply, update(socket, :show_playlist, &(!&1))}
  end

  @impl true
  def handle_event("set_playlist", %{"decade" => decade}, socket) do
    Rooms.set_playlist(socket.assigns.room_code, decade)
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
  def handle_event("update_track", _params, socket) do
    Rooms.update_track(socket.assigns.room_code)
    {:noreply, socket}
  end

  # ------------------------------------------------------------------
  # Components
  # ------------------------------------------------------------------
  def room_info(assigns) do
    ~H"""
    <div class="w-full text-center space-y-2">
      <div class="text-sm text-gray-500">{@room_code}</div>
      <div class="text-sm text-gray-500">
        <%= if length(@users) == 1 do %>
          <span class={if Enum.at(@users, 0).user_id == @user_id, do: "font-bold"}>
            {Enum.at(@users, 0).user_id}
          </span>
          {gettext("is here")}
        <% else %>
          <span class={if Enum.at(@users, 0).user_id == @user_id, do: "font-bold"}>
            {Enum.at(@users, 0).user_id}
          </span>
          {gettext("is joined by")}
          <%= for {user, index} <- Enum.with_index(Enum.drop(@users, 1)) do %>
            <span class={if user.user_id == @user_id, do: "font-bold"}>{user.user_id}</span>{if index <
                                                                                                  length(
                                                                                                    Enum.drop(
                                                                                                      @users,
                                                                                                      1
                                                                                                    )
                                                                                                  ) -
                                                                                                    1,
                                                                                                do:
                                                                                                  ", "}
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def pling_button(assigns) do
    assigns = assign(assigns, :disabled?, !assigns.leader? && !assigns.playing?)

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
                  <.button
                    phx-click="adjust_score"
                    phx-value-user_id={user.user_id}
                    phx-value-amount="1"
                  >
                    +1
                  </.button>
                  <.button
                    phx-click="adjust_score"
                    phx-value-user_id={user.user_id}
                    phx-value-amount="-1"
                  >
                    -1
                  </.button>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @leader? do %>
        <div class="flex justify-center space-x-2">
          <.button phx-click="update_track">
            {gettext("Next Track")}
          </.button>
        </div>
      <% end %>
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

    count_value = Map.get(assigns.scores || %{}, assigns.color, 0)

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
          {@count}
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
    <div class="col-span-3 grid grid-cols-3 place-items-center gap-4 rounded w-full">
      <.playlist decade="50s" active?={@selection.playlist == "50s"} />
      <.playlist decade="60s" active?={@selection.playlist == "60s"} />
      <.playlist decade="70s" active?={@selection.playlist == "70s"} />
      <.playlist decade="80s" active?={@selection.playlist == "80s"} />
      <.playlist decade="90s" active?={@selection.playlist == "90s"} />
      <.playlist decade="mix" active?={@selection.playlist == "mix"} />
    </div>
    """
  end
end
