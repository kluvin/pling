defmodule PlingWeb.SmokeTest do
  use ExUnit.Case
  use PlingWeb.ConnCase

  test "smoke test - root path redirects to login" do
    conn = get(build_conn(), "/")
    assert redirected_to(conn, 302) =~ "/login"
  end
end
