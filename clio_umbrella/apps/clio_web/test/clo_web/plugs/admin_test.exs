defmodule CloWeb.Plugs.AdminTest do
  use CloWeb.ConnCase, async: true

  alias CloWeb.Plugs.Admin

  describe "call/2" do
    test "allows admin users through", %{conn: conn} do
      conn =
        conn
        |> assign(:current_user, %{role: :admin, username: "admin"})
        |> Admin.call([])

      refute conn.halted
    end

    test "blocks non-admin users with 403", %{conn: conn} do
      conn =
        conn
        |> assign(:current_user, %{role: :user, username: "analyst"})
        |> Admin.call([])

      assert conn.halted
      assert conn.status == 403
    end

    test "blocks when no user assigned", %{conn: conn} do
      conn = Admin.call(conn, [])

      assert conn.halted
      assert conn.status == 403
    end
  end
end
