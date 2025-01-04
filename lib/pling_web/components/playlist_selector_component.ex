defmodule PlingWeb.Components.PlaylistSelector do
  use Phoenix.Component

  def playlist(assigns) do
    active? = assigns[:active?]

    active_class =
      if active?, do: "bg-indigo-900 text-indigo-50", else: "bg-indigo-50 text-indigo-900"

    assigns = assign(assigns, :active_class, active_class)

    ~H"""
    <button
      class={"px-4 py-2 rounded " <> @active_class}
      phx-click="set_playlist"
      phx-value-playlist_id={@id}
    >
      {@name}
    </button>
    """
  end
end
