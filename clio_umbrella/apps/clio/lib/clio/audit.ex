defmodule Clio.Audit do
  @moduledoc "Audit trail context for logging security, data, system, and audit events."

  alias Clio.Audit.Writer

  def log_security(type, username, metadata \\ %{}, details \\ %{}) do
    Writer.log_event("security", %{
      "type" => type,
      "severity" => severity_for(type),
      "username" => username,
      "metadata" => metadata,
      "details" => details
    })
  end

  def log_data(type, username, metadata \\ %{}, details \\ %{}) do
    Writer.log_event("data", %{
      "type" => type,
      "severity" => "info",
      "username" => username,
      "metadata" => metadata,
      "details" => details
    })
  end

  def log_system(type, metadata \\ %{}, details \\ %{}) do
    Writer.log_event("system", %{
      "type" => type,
      "severity" => "info",
      "username" => "system",
      "metadata" => metadata,
      "details" => details
    })
  end

  def log_audit(type, username, metadata \\ %{}, details \\ %{}) do
    Writer.log_event("audit", %{
      "type" => type,
      "severity" => "info",
      "username" => username,
      "metadata" => metadata,
      "details" => details
    })
  end

  defp severity_for(type) do
    case type do
      t when t in ~w(security_login_failure security_csrf_failure) -> "high"
      t when t in ~w(security_login_attempt security_password_change security_token_revoke) -> "medium"
      _ -> "info"
    end
  end
end
