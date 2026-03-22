defmodule CloWeb.HealthController do
  @moduledoc "Public health check endpoint."
  use CloWeb, :controller

  def check(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end
end
