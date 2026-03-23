defmodule CloWeb.RelationsLive do
  @moduledoc "Log relations view with filtering by type, user commands, and MAC addresses."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Relations",
       active_view: :relations,
       filter: :all,
       relations: [],
       expanded_entities: MapSet.new(),
       commands: [],
       mac_addresses: []
     )
     |> load_relations()}
  end

  defp load_relations(socket) do
    case socket.assigns.filter do
      :all ->
        assign(socket, relations: Clio.RelationsContext.list_relations())
      :ip ->
        assign(socket, relations: Clio.RelationsContext.list_relations(type: "internal_ip"))
      :hostname ->
        assign(socket, relations: Clio.RelationsContext.list_relations(type: "hostname"))
      :domain ->
        assign(socket, relations: Clio.RelationsContext.list_relations(type: "domain"))
      :commands ->
        assign(socket, commands: Clio.RelationsContext.get_commands())
      :mac ->
        assign(socket, mac_addresses: Clio.RelationsContext.get_mac_addresses())
    end
  end

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    {:noreply, socket |> assign(filter: String.to_atom(filter), expanded_entities: MapSet.new()) |> load_relations()}
  end

  def handle_event("refresh", _params, socket) do
    Clio.RelationsContext.trigger_analysis()
    {:noreply, load_relations(socket)}
  end

  def handle_event("toggle_entity", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded_entities
    expanded = if MapSet.member?(expanded, id), do: MapSet.delete(expanded, id), else: MapSet.put(expanded, id)
    {:noreply, assign(socket, expanded_entities: expanded)}
  end

  def handle_event("logout", _params, socket) do
    user = socket.assigns.current_user
    if user[:jti], do: Clio.Auth.revoke_token(user.jti, user.username)
    {:noreply, redirect(socket, to: "/login")}
  end

  @impl true
  def handle_info({:switch_operation, op_id}, socket) do
    user = socket.assigns.current_user
    Clio.Operations.set_primary_operation(user.username, op_id)
    operations = Clio.Operations.get_user_operations(user.username)
    active_op = case Clio.Operations.get_active_operation(user.username) do
      {:ok, op} -> op
      _ -> nil
    end
    {:noreply, socket |> assign(user_operations: operations, active_operation: active_op) |> load_relations()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <div class="flex items-center gap-3 mb-6">
        <.icon name="hero-share" class="w-8 h-8 text-blue-400" />
        <h2 class="text-2xl font-bold text-white">Log Relations</h2>
      </div>

      <%!-- Filter buttons --%>
      <div class="flex flex-wrap items-center gap-2 mb-6">
        <button phx-click="refresh" class="px-3 py-2 bg-gray-700 text-gray-300 rounded-md hover:bg-gray-600">
          <.icon name="hero-arrow-path" class="w-5 h-5" />
        </button>
        <%= for {label, value} <- [{"All Relations", :all}, {"IP Relations", :ip}, {"Hostname Relations", :hostname}, {"Domain Relations", :domain}, {"User Commands", :commands}, {"MAC Address", :mac}] do %>
          <button
            phx-click="set_filter"
            phx-value-filter={value}
            class={"px-4 py-2 rounded-md transition-colors #{if @filter == value, do: "bg-blue-600 text-white", else: "bg-gray-700 text-white hover:bg-gray-600"}"}
          >
            {label}
          </button>
        <% end %>
      </div>

      <%!-- Content --%>
      <%= if @filter == :commands do %>
        <.commands_view commands={@commands} expanded={@expanded_entities} />
      <% end %>
      <%= if @filter == :mac do %>
        <.mac_view macs={@mac_addresses} />
      <% end %>
      <%= if @filter in [:all, :ip, :hostname, :domain] do %>
        <.relations_list relations={@relations} expanded={@expanded_entities} />
      <% end %>
    </div>
    """
  end

  defp relations_list(assigns) do
    grouped = Enum.group_by(assigns.relations, fn r -> {r.source_type, r.source_value} end)
    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <div class="space-y-2">
      <%= for {{source_type, source_value}, rels} <- @grouped do %>
        <div class="bg-gray-800 rounded-lg">
          <button
            phx-click="toggle_entity"
            phx-value-id={"#{source_type}-#{source_value}"}
            class="w-full px-4 py-3 flex items-center justify-between hover:bg-gray-700 rounded-lg transition-colors"
          >
            <div class="flex items-center gap-3">
              <.relation_icon type={source_type} />
              <span class="font-bold text-white">{source_value}</span>
              <span class="text-gray-400 text-sm">({length(rels)} connections)</span>
            </div>
            <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
          </button>

          <%= if MapSet.member?(@expanded, "#{source_type}-#{source_value}") do %>
            <div class="px-4 pb-4 space-y-2">
              <%= for rel <- rels do %>
                <div class="bg-gray-700/50 rounded p-3 flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <.relation_icon type={rel.target_type} />
                    <span class="text-white">{rel.target_value}</span>
                    <span class="text-gray-500 text-xs">{rel.target_type}</span>
                  </div>
                  <div class="flex items-center gap-4 text-xs text-gray-400">
                    <span>Strength: {rel.strength || 0}</span>
                    <span>Count: {rel.connection_count}</span>
                    <span>First: {format_ts(rel.first_seen)}</span>
                    <span>Last: {format_ts(rel.last_seen)}</span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
      <%= if Enum.empty?(@relations) do %>
        <p class="text-gray-500 text-center py-8">No relations found.</p>
      <% end %>
    </div>
    """
  end

  defp commands_view(assigns) do
    grouped = Enum.group_by(assigns.commands, & &1.source_value)
    assigns = assign(assigns, :grouped, grouped)

    ~H"""
    <div class="space-y-2">
      <%= for {username, cmds} <- @grouped do %>
        <div class="bg-gray-800 rounded-lg">
          <button
            phx-click="toggle_entity"
            phx-value-id={"cmd-#{username}"}
            class="w-full px-4 py-3 flex items-center justify-between hover:bg-gray-700 rounded-lg transition-colors"
          >
            <div class="flex items-center gap-3">
              <.icon name="hero-user" class="w-5 h-5 text-yellow-400" />
              <span class="font-bold text-white">{username}</span>
              <span class="text-gray-400 text-sm">({length(cmds)} commands)</span>
            </div>
            <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
          </button>

          <%= if MapSet.member?(@expanded, "cmd-#{username}") do %>
            <div class="px-4 pb-4 space-y-1">
              <%= for cmd <- cmds do %>
                <div class="bg-gray-700/50 rounded p-2 flex items-center justify-between">
                  <span class="text-yellow-300 text-sm font-mono">{cmd.target_value}</span>
                  <span class="text-xs text-gray-400">{format_ts(cmd.last_seen)}</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp mac_view(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= for rel <- @macs do %>
        <div class="bg-gray-800 rounded-lg px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <.icon name="hero-signal" class="w-5 h-5 text-cyan-400" />
            <span class="text-cyan-300 font-mono">
              {if rel.source_type == "mac_address", do: rel.source_value, else: rel.target_value}
            </span>
          </div>
          <div class="flex items-center gap-3">
            <span class="text-blue-300">
              {if rel.source_type == "mac_address", do: rel.target_value, else: rel.source_value}
            </span>
            <span class="text-xs text-gray-400">{format_ts(rel.last_seen)}</span>
          </div>
        </div>
      <% end %>
      <%= if Enum.empty?(@macs) do %>
        <p class="text-gray-500 text-center py-8">No MAC address mappings found.</p>
      <% end %>
    </div>
    """
  end

  defp relation_icon(%{type: "domain"} = assigns), do: ~H|<.icon name="hero-globe-alt" class="w-5 h-5 text-purple-400" />|
  defp relation_icon(%{type: "internal_ip"} = assigns), do: ~H|<.icon name="hero-signal" class="w-5 h-5 text-green-400" />|
  defp relation_icon(%{type: "external_ip"} = assigns), do: ~H|<.icon name="hero-signal" class="w-5 h-5 text-green-400" />|
  defp relation_icon(%{type: "hostname"} = assigns), do: ~H|<.icon name="hero-server" class="w-5 h-5 text-blue-400" />|
  defp relation_icon(%{type: "username"} = assigns), do: ~H|<.icon name="hero-user" class="w-5 h-5 text-yellow-400" />|
  defp relation_icon(assigns), do: ~H|<.icon name="hero-link" class="w-5 h-5 text-gray-400" />|

  defp format_ts(nil), do: "-"
  defp format_ts(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_ts(other), do: to_string(other)
end
