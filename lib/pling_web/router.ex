defmodule PlingWeb.Router do
  use PlingWeb, :router
  import Phoenix.LiveView.Router

  import Plug.BasicAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :upcase_room_code
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dashboard_auth do
    plug :basic_auth, username: "blur", password: "thenarcissist"
  end

  scope "/", PlingWeb do
    pipe_through [:browser, :dashboard_auth]
  end

  scope "/", PlingWeb do
    pipe_through :browser

    get "/login", LoginController, :login
    get "/logout", LoginController, :logout

    pipe_through :require_login
    live "/", HomeLive
    live "/:game_mode/:room_code", RoomLive
  end

  pipeline :require_login do
    plug :ensure_authenticated
  end

  defp ensure_authenticated(conn, _opts) do
    if get_session(conn, :user_id) do
      conn
    else
      conn
      |> redirect(to: "/login")
      |> halt()
    end
  end

  defp upcase_room_code(conn, _opts) do
    case conn.path_params do
      %{"room_code" => room_code} = params ->
        %{conn | path_params: %{params | "room_code" => String.upcase(room_code)}}

      _ ->
        conn
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", PlingWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pling, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PlingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
