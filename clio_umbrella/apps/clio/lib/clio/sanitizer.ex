defmodule Clio.Sanitizer do
  @moduledoc """
  Input sanitization module for XSS prevention and field validation.
  Uses HtmlSanitizeEx with strict config. Special handling for shell-syntax fields.
  """

  @ipv4_regex ~r/^(\d{1,3}\.){3}\d{1,3}$/
  @ipv6_regex ~r/^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$/
  @mac_regex ~r/^([0-9A-Fa-f]{2}[:\-.]?){5}[0-9A-Fa-f]{2}$/
  @username_allowed ~r/[^a-zA-Z0-9_\\\/\-]/

  # Fields that preserve shell syntax (only escape < and >)
  @shell_fields ~w(command notes filename secrets)a

  def sanitize_params(params) when is_map(params) do
    try do
      Map.new(params, fn {k, v} ->
        key = if is_binary(k), do: String.to_existing_atom(k), else: k
        {k, sanitize_field(key, v)}
      end)
    rescue
      ArgumentError -> Map.new(params, fn {k, v} -> {k, sanitize_value(v)} end)
    end
  end

  def sanitize_params(params), do: params

  def sanitize_field(field, value) when field in @shell_fields and is_binary(value) do
    value
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  def sanitize_field(:username, value) when is_binary(value) do
    String.replace(value, @username_allowed, "")
  end

  def sanitize_field(:internal_ip, value) when is_binary(value), do: validate_ip(value)
  def sanitize_field(:external_ip, value) when is_binary(value), do: validate_ip(value)

  def sanitize_field(:mac_address, value) when is_binary(value) do
    normalize_mac(value)
  end

  def sanitize_field(_field, value) when is_binary(value) do
    sanitize_value(value)
  end

  def sanitize_field(_field, value), do: value

  def sanitize_value(value) when is_binary(value) do
    HtmlSanitizeEx.strip_tags(value)
  end

  def sanitize_value(value) when is_list(value) do
    Enum.map(value, &sanitize_value/1)
  end

  def sanitize_value(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, sanitize_value(v)} end)
  end

  def sanitize_value(value), do: value

  def validate_ip(value) do
    if value =~ @ipv4_regex or value =~ @ipv6_regex do
      value
    else
      nil
    end
  end

  def normalize_mac(value) do
    if value =~ @mac_regex do
      value
      |> String.upcase()
      |> String.replace(~r/[:\.]/, "-")
    else
      nil
    end
  end

  def validate_username(username) when is_binary(username) do
    String.replace(username, @username_allowed, "")
  end
end
