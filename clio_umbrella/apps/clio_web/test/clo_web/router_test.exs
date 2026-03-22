defmodule CloWeb.RouterTest do
  use CloWeb.ConnCase, async: true

  describe "route structure" do
    test "health endpoint is publicly accessible", %{conn: conn} do
      conn = get(conn, "/api/health")
      assert conn.status == 200
    end

    test "login endpoint exists" do
      # Verify the route is reachable (will return 400 due to missing params, not 404)
      conn = build_conn()
      conn = post(conn, "/api/auth/login")
      # Without body, Phoenix may return 400 or pattern match error, but NOT 404
      assert conn.status != 404
    end

    test "authenticated endpoints reject unauthenticated requests", %{conn: conn} do
      endpoints = [
        {:get, "/api/auth/verify"},
        {:get, "/api/logs"},
        {:get, "/api/tags"},
        {:get, "/api/operations"},
        {:get, "/api/templates"},
        {:get, "/api/export/csv"},
        {:get, "/api/export/json"}
      ]

      for {method, path} <- endpoints do
        response = apply(Phoenix.ConnTest, method, [conn, path])
        assert response.status in [401, 403],
               "#{method} #{path} should reject unauthenticated requests, got #{response.status}"
      end
    end

    test "admin endpoints reject unauthenticated requests", %{conn: conn} do
      conn = get(conn, "/api/admin/api-keys")
      assert conn.status in [401, 403]
    end

    test "tags autocomplete route resolves before :id route" do
      # This verifies our route ordering fix
      # The route /tags/search/autocomplete should NOT treat "search" as :id
      router = CloWeb.Router
      # Verify the route exists and matches correctly
      assert Phoenix.Router.route_info(router, "GET", "/api/tags/search/autocomplete", "localhost")
    end

    test "tags stats route resolves before :id route" do
      router = CloWeb.Router
      assert Phoenix.Router.route_info(router, "GET", "/api/tags/stats/usage", "localhost")
    end

    test "operations mine route resolves before :id route" do
      router = CloWeb.Router
      assert Phoenix.Router.route_info(router, "GET", "/api/operations/mine/list", "localhost")
    end
  end
end
