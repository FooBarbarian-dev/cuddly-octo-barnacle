defmodule CloWeb.Plugs.RateLimit do
  @moduledoc "Plug for rate limiting requests using Hammer."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 100)
    period = Keyword.get(opts, :period, 60_000)
    key = rate_limit_key(conn)

    case Hammer.check_rate(key, period, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(429)
        |> Phoenix.Controller.json(%{error: "Too many requests"})
        |> halt()
    end
  end

  defp rate_limit_key(conn) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    "rate_limit:#{ip}:#{conn.request_path}"
  end
end
