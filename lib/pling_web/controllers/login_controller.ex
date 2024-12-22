defmodule PlingWeb.LoginController do
  use PlingWeb, :controller
  alias Pling.Names

  def login(conn, _params) do
    conn =
      case get_session(conn, :user_id) do
        nil ->
          conn
          |> put_session(:user_id, Names.generate())
          |> configure_session(renew: true)

        _existing_user ->
          conn
      end

    redirect(conn, to: "/")
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/login")
  end
end
