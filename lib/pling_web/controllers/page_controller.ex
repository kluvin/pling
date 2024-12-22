defmodule PlingWeb.PageController do
  use PlingWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def create_room(conn, _params) do
    room_code = generate_room_code()
    redirect(conn, to: "/session/#{room_code}")
  end

  # Helper function to generate room code
  defp generate_room_code do
    # Generate a random 4-character string
    :crypto.strong_rand_bytes(2)
    |> Base.encode16()
    |> String.downcase()
  end
end
