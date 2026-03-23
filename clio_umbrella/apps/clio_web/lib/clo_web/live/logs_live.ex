defmodule CloWeb.LogsLive do
  @moduledoc "Main logs workspace with card view, inline editing, tags, evidence, search, and pagination."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @default_visible_fields %{
    internal_ip: true, external_ip: true, hostname: true, domain: true,
    username: true, command: true, filename: true, status: true,
    mac_address: false, pid: false, notes: false
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Logs",
       active_view: :logs,
       # Data
       logs: [],
       total_count: 0,
       # Pagination
       page: 1,
       per_page: 50,
       # Search & Filter
       search_query: "",
       search_field: "all",
       start_date: "",
       end_date: "",
       selected_tags: [],
       available_tags: [],
       # View mode
       view_mode: :card,
       # Interaction state
       expanded_rows: MapSet.new(),
       show_evidence: MapSet.new(),
       editing: nil,
       editing_value: "",
       visible_fields: @default_visible_fields,
       show_secrets: MapSet.new(),
       show_all_tags: MapSet.new(),
       # Tag modal
       tag_modal_log_id: nil,
       tag_search: "",
       tag_autocomplete: [],
       tag_modal_selected: [],
       # Template
       show_templates: false,
       templates: [],
       template_name: "",
       # Filters visible
       show_filters: false
     )
     |> load_data()}
  end

  defp load_data(socket) do
    user = socket.assigns.current_user
    page = socket.assigns.page
    per_page = socket.assigns.per_page

    opts = [
      limit: per_page,
      offset: (page - 1) * per_page
    ]

    opts = add_search_opts(opts, socket.assigns)

    logs = Clio.Logs.list_logs(user, opts)
    all_tags = Clio.Tags.list_tags()

    # Build tag map for each log
    log_tags =
      Map.new(logs, fn log ->
        {log.id, log.tags || []}
      end)

    # Count total (approximate from loaded data or do a count query)
    total = if length(logs) < per_page, do: (page - 1) * per_page + length(logs), else: page * per_page + 1

    assign(socket,
      logs: logs,
      total_count: total,
      available_tags: all_tags,
      log_tags: log_tags
    )
  end

  defp add_search_opts(opts, assigns) do
    opts
    |> maybe_add_search(assigns.search_field, assigns.search_query)
    |> maybe_add_date(:date_from, assigns.start_date)
    |> maybe_add_date(:date_to, assigns.end_date)
  end

  defp maybe_add_search(opts, _field, ""), do: opts
  defp maybe_add_search(opts, "all", query) do
    Keyword.put(opts, :hostname, query)
  end
  defp maybe_add_search(opts, field, query) do
    Keyword.put(opts, String.to_existing_atom(field), query)
  end

  defp maybe_add_date(opts, _key, ""), do: opts
  defp maybe_add_date(opts, key, date_str) do
    case DateTime.from_iso8601(date_str <> ":00Z") do
      {:ok, dt, _} -> Keyword.put(opts, key, dt)
      _ -> opts
    end
  end

  # ── Event Handlers ──

  @impl true
  def handle_event("toggle_expand", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = socket.assigns.expanded_rows

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, assign(socket, expanded_rows: expanded)}
  end

  def handle_event("toggle_lock", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    log = Enum.find(socket.assigns.logs, &(&1.id == id))

    result =
      if log.locked,
        do: Clio.Logs.unlock_log(id, user),
        else: Clio.Logs.lock_log(id, user.username)

    case result do
      {:ok, _} -> {:noreply, load_data(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Lock error: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_evidence", %{"id" => id}, socket) do
    id = String.to_integer(id)
    show = socket.assigns.show_evidence

    show =
      if MapSet.member?(show, id),
        do: MapSet.delete(show, id),
        else: MapSet.put(show, id)

    {:noreply, assign(socket, show_evidence: show)}
  end

  def handle_event("toggle_secrets", %{"id" => id}, socket) do
    id = String.to_integer(id)
    secrets = socket.assigns.show_secrets

    secrets =
      if MapSet.member?(secrets, id),
        do: MapSet.delete(secrets, id),
        else: MapSet.put(secrets, id)

    {:noreply, assign(socket, show_secrets: secrets)}
  end

  def handle_event("start_edit", %{"field" => field, "id" => id, "value" => value}, socket) do
    {:noreply, assign(socket, editing: {String.to_integer(id), String.to_atom(field)}, editing_value: value || "")}
  end

  def handle_event("save_edit", %{"field" => field, "log-id" => id} = params, socket) do
    value = params["value"] || ""
    id = String.to_integer(id)
    field_atom = String.to_atom(field)
    user = socket.assigns.current_user

    case Clio.Logs.update_log(id, %{field_atom => value}, user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(editing: nil, editing_value: "")
         |> load_data()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Save failed: #{inspect(reason)}")}
    end
  end

  def handle_event("handle_edit_keydown", %{"key" => "Enter"} = params, socket) do
    handle_event("save_edit", params, socket)
  end

  def handle_event("handle_edit_keydown", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, editing: nil, editing_value: "")}
  end

  def handle_event("handle_edit_keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_current_edit", _params, socket) do
    case socket.assigns.editing do
      {id, field} ->
        handle_event("save_edit", %{
          "field" => to_string(field),
          "log-id" => to_string(id),
          "value" => socket.assigns.editing_value
        }, socket)
      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing: nil, editing_value: "")}
  end

  def handle_event("delete_log", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Clio.Logs.delete_log(id, socket.assigns.current_user) do
      {:ok, _} -> {:noreply, load_data(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Delete failed: #{inspect(reason)}")}
    end
  end

  def handle_event("add_row", _params, socket) do
    user = socket.assigns.current_user
    attrs = %{timestamp: DateTime.utc_now(), analyst: user.username}

    case Clio.Logs.create_log(attrs, user) do
      {:ok, _log} -> {:noreply, load_data(socket)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Create failed: #{inspect(reason)}")}
    end
  end

  # ── Search & Filter ──

  def handle_event("search_changed", %{"value" => query}, socket) do
    {:noreply, socket |> assign(search_query: query, page: 1) |> load_data()}
  end

  def handle_event("search_field_changed", %{"search_field" => field}, socket) do
    {:noreply, socket |> assign(search_field: field, page: 1) |> load_data()}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(search_query: "", page: 1) |> load_data()}
  end

  def handle_event("date_range_changed", params, socket) do
    start_date = params["start_date"] || ""
    end_date = params["end_date"] || ""
    {:noreply, socket |> assign(start_date: start_date, end_date: end_date, page: 1) |> load_data()}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, show_filters: !socket.assigns.show_filters)}
  end

  # ── View mode ──

  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, view_mode: String.to_atom(mode))}
  end

  # ── Pagination ──

  def handle_event("go_to_page", %{"page" => page}, socket) do
    page = String.to_integer(page) |> max(1)
    {:noreply, socket |> assign(page: page) |> load_data()}
  end

  def handle_event("change_per_page", %{"per_page" => per_page}, socket) do
    {:noreply, socket |> assign(per_page: String.to_integer(per_page), page: 1) |> load_data()}
  end

  # ── Tags ──

  def handle_event("open_tag_modal", %{"log-id" => id}, socket) do
    {:noreply, assign(socket, tag_modal_log_id: String.to_integer(id), tag_search: "", tag_autocomplete: [], tag_modal_selected: [])}
  end

  def handle_event("close_tag_modal", _params, socket) do
    {:noreply, assign(socket, tag_modal_log_id: nil)}
  end

  def handle_event("tag_search", %{"value" => term}, socket) do
    results = if String.length(term) > 0, do: Clio.Tags.autocomplete(term), else: []
    {:noreply, assign(socket, tag_search: term, tag_autocomplete: results)}
  end

  def handle_event("select_tag_from_autocomplete", %{"id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    log_id = socket.assigns.tag_modal_log_id
    user = socket.assigns.current_user

    Clio.Tags.add_tag_to_log(log_id, tag_id, user.username)
    {:noreply, socket |> assign(tag_modal_log_id: nil) |> load_data()}
  end

  def handle_event("create_and_add_tag", _params, socket) do
    name = socket.assigns.tag_search
    log_id = socket.assigns.tag_modal_log_id
    user = socket.assigns.current_user

    case Clio.Tags.get_or_create(name, created_by: user.username) do
      {:ok, tag} ->
        Clio.Tags.add_tag_to_log(log_id, tag.id, user.username)
        {:noreply, socket |> assign(tag_modal_log_id: nil) |> load_data()}
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to create tag")}
    end
  end

  def handle_event("remove_tag", %{"tag-id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    # Find which log this tag belongs to from context
    # We need to search through log_tags to find the log_id
    log_id = find_log_for_tag(socket.assigns.log_tags, tag_id)

    if log_id do
      case Clio.Tags.remove_tag_from_log(log_id, tag_id) do
        {:ok, _} -> {:noreply, load_data(socket)}
        {:error, :native_operation_tag_protected} ->
          {:noreply, put_flash(socket, :error, "Cannot remove the native operation tag")}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to remove tag")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_show_all_tags", %{"log-id" => id}, socket) do
    id = String.to_integer(id)
    show_all = socket.assigns.show_all_tags

    show_all =
      if MapSet.member?(show_all, id),
        do: MapSet.delete(show_all, id),
        else: MapSet.put(show_all, id)

    {:noreply, assign(socket, show_all_tags: show_all)}
  end

  # ── Field Settings ──

  def handle_event("restore_field_settings", settings, socket) do
    visible =
      Map.new(settings, fn {k, v} -> {String.to_existing_atom(k), v} end)

    {:noreply, assign(socket, visible_fields: Map.merge(@default_visible_fields, visible))}
  end

  def handle_event("toggle_field_visibility", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)
    current = Map.get(socket.assigns.visible_fields, field, true)
    visible = Map.put(socket.assigns.visible_fields, field, !current)

    {:noreply,
     socket
     |> assign(visible_fields: visible)
     |> push_event("save_field_settings", visible)}
  end

  # ── Templates ──

  def handle_event("toggle_templates", _params, socket) do
    templates = if !socket.assigns.show_templates, do: Clio.Templates.list(), else: socket.assigns.templates
    {:noreply, assign(socket, show_templates: !socket.assigns.show_templates, templates: templates)}
  end

  def handle_event("save_as_template", %{"id" => id}, socket) do
    id = String.to_integer(id)
    log = Enum.find(socket.assigns.logs, &(&1.id == id))
    user = socket.assigns.current_user

    template_data =
      Map.take(log, [:internal_ip, :external_ip, :hostname, :domain, :username,
                      :command, :notes, :filename, :status, :hash_algorithm, :hash_value, :pid])
      |> Map.new(fn {k, v} -> {to_string(k), v} end)

    name = "Template from log #{id}"
    Clio.Templates.create(%{name: name, template_data: template_data}, user.username)
    {:noreply, put_flash(socket, :info, "Template saved")}
  end

  def handle_event("load_template", %{"id" => template_id, "log-id" => log_id}, socket) do
    template_id = String.to_integer(template_id)
    log_id = String.to_integer(log_id)
    user = socket.assigns.current_user

    case Clio.Templates.get(template_id) do
      {:ok, template} ->
        attrs = Map.new(template.template_data, fn {k, v} -> {String.to_existing_atom(k), v} end)
        Clio.Logs.update_log(log_id, attrs, user)
        {:noreply, load_data(socket)}
      _ ->
        {:noreply, put_flash(socket, :error, "Template not found")}
    end
  end

  def handle_event("delete_template", %{"id" => id}, socket) do
    Clio.Templates.delete(String.to_integer(id))
    templates = Clio.Templates.list()
    {:noreply, assign(socket, templates: templates)}
  end

  # ── Operation switching ──

  @impl true
  def handle_info({:switch_operation, op_id}, socket) do
    user = socket.assigns.current_user
    Clio.Operations.set_primary_operation(user.username, op_id)

    operations = Clio.Operations.get_user_operations(user.username)
    active_op = case Clio.Operations.get_active_operation(user.username) do
      {:ok, op} -> op
      _ -> nil
    end

    {:noreply,
     socket
     |> assign(user_operations: operations, active_operation: active_op, page: 1)
     |> load_data()}
  end

  def handle_event("logout", _params, socket) do
    user = socket.assigns.current_user
    if user[:jti], do: Clio.Auth.revoke_token(user.jti, user.username)
    {:noreply, redirect(socket, to: "/login")}
  end

  # ── Helpers ──

  defp find_log_for_tag(log_tags, tag_id) do
    Enum.find_value(log_tags, fn {log_id, tags} ->
      if Enum.any?(tags, &(&1.id == tag_id)), do: log_id
    end)
  end

  defp is_editing?(editing, log_id, field) do
    editing == {log_id, field}
  end

  defp can_edit?(log, current_user) do
    cond do
      not log.locked -> true
      log.locked_by == current_user.username -> true
      current_user.role == :admin -> true
      true -> false
    end
  end

  # ── Render ──

  @impl true
  def render(assigns) do
    ~H"""
    <div id="logs-view" phx-hook="SaveShortcut">
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <%!-- Sub-header --%>
      <div class="flex flex-wrap items-center justify-between gap-2 mb-4">
        <div class="flex items-center gap-2">
          <button
            phx-click="set_view_mode"
            phx-value-mode="card"
            class={nav_btn_class(@view_mode == :card)}
          >
            Card View
          </button>
          <button
            phx-click="set_view_mode"
            phx-value-mode="table"
            class={nav_btn_class(@view_mode == :table)}
          >
            Table View
          </button>
          <button phx-click="toggle_filters" class="px-3 py-2 bg-gray-700 text-gray-300 rounded-md hover:bg-gray-600 text-sm">
            <.icon name="hero-magnifying-glass" class="w-4 h-4 inline" /> Filters
          </button>
        </div>
        <button phx-click="add_row" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2">
          <.icon name="hero-plus" class="w-5 h-5" /> Add Row
        </button>
      </div>

      <%!-- Filters --%>
      <%= if @show_filters do %>
        <div class="bg-gray-800 rounded-lg p-4 mb-4 space-y-3">
          <.search_filter query={@search_query} field={@search_field} />
          <.date_range_filter start_date={@start_date} end_date={@end_date} />
        </div>
      <% end %>

      <%!-- Card View --%>
      <div id="logs-list" phx-hook="CardFieldSettings">
        <%= if @view_mode == :card do %>
          <%= for log <- @logs do %>
            <.log_card
              log={log}
              current_user={@current_user}
              is_expanded={MapSet.member?(@expanded_rows, log.id)}
              show_evidence={MapSet.member?(@show_evidence, log.id)}
              show_secrets={MapSet.member?(@show_secrets, log.id)}
              show_all_tags={MapSet.member?(@show_all_tags, log.id)}
              visible_fields={@visible_fields}
              editing={@editing}
              editing_value={@editing_value}
              tags={Map.get(@log_tags, log.id, [])}
              tag_modal_log_id={@tag_modal_log_id}
              tag_search={@tag_search}
              tag_autocomplete={@tag_autocomplete}
            />
          <% end %>
        <% else %>
          <.table_view logs={@logs} current_user={@current_user} />
        <% end %>
      </div>

      <.pagination page={@page} per_page={@per_page} total={@total_count} />

      <%!-- Tag Input Modal --%>
      <%= if @tag_modal_log_id do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4" phx-click="close_tag_modal">
          <div class="max-w-2xl w-full bg-gray-800 rounded-lg p-4" phx-click-away="close_tag_modal">
            <h3 class="text-lg font-semibold text-white mb-4">Add Tag</h3>
            <input
              type="text"
              value={@tag_search}
              phx-keyup="tag_search"
              phx-debounce="300"
              placeholder="Search or create tag..."
              class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-2 rounded-md mb-3 focus:outline-none focus:ring-2 focus:ring-blue-500"
              autofocus
            />
            <div class="max-h-60 overflow-y-auto space-y-1">
              <%= for tag <- @tag_autocomplete do %>
                <button
                  phx-click="select_tag_from_autocomplete"
                  phx-value-id={tag.id}
                  class="w-full text-left px-3 py-2 rounded hover:bg-gray-700 flex items-center gap-2"
                >
                  <span
                    class="w-3 h-3 rounded-full inline-block"
                    style={"background-color: #{tag.color || "#6B7280"}"}
                  ></span>
                  <span class="text-white">{tag.name}</span>
                  <span class="text-gray-500 text-xs">{tag.category}</span>
                </button>
              <% end %>
              <%= if @tag_search != "" and Enum.empty?(@tag_autocomplete) do %>
                <button
                  phx-click="create_and_add_tag"
                  class="w-full text-left px-3 py-2 rounded hover:bg-gray-700 text-blue-400"
                >
                  Create new tag "{@tag_search}"
                </button>
              <% end %>
            </div>
            <div class="flex justify-end mt-4">
              <button phx-click="close_tag_modal" class="px-4 py-2 bg-gray-700 text-gray-300 rounded-md hover:bg-gray-600">
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Log Card Component ──

  defp log_card(assigns) do
    is_admin = assigns.current_user.role == :admin
    can_edit = can_edit?(assigns.log, assigns.current_user)
    assigns = assign(assigns, is_admin: is_admin, can_edit: can_edit)

    ~H"""
    <div class={"mb-2 rounded-lg #{if @log.locked, do: "bg-gray-900", else: "bg-gray-800"}"}>
      <%!-- Header Row --%>
      <div
        class="px-4 py-3 flex items-center justify-between cursor-pointer hover:bg-gray-700 transition-colors"
        phx-click="toggle_expand"
        phx-value-id={@log.id}
      >
        <div class="flex items-center gap-x-3 overflow-hidden">
          <%!-- Expand chevron --%>
          <%= if @is_expanded do %>
            <.icon name="hero-chevron-down" class="w-5 h-5 text-white flex-shrink-0" />
          <% else %>
            <.icon name="hero-chevron-right" class="w-5 h-5 text-white flex-shrink-0" />
          <% end %>

          <%!-- Lock button --%>
          <button
            phx-click="toggle_lock"
            phx-value-id={@log.id}
            class="flex-shrink-0 p-1 rounded hover:bg-gray-600 transition-colors"
            title={if @log.locked, do: "Locked by #{@log.locked_by}", else: "Unlocked"}
          >
            <%= if @log.locked do %>
              <.icon name="hero-lock-closed" class="w-5 h-5 text-red-400" />
            <% else %>
              <.icon name="hero-lock-open" class="w-5 h-5 text-green-400" />
            <% end %>
          </button>

          <%!-- Evidence button --%>
          <button
            phx-click="toggle_evidence"
            phx-value-id={@log.id}
            class="flex-shrink-0 p-1 rounded hover:bg-gray-600 transition-colors"
          >
            <.icon name="hero-document-text" class={"w-5 h-5 #{if @show_evidence, do: "text-blue-400", else: "text-gray-400"}"} />
          </button>

          <%!-- Timestamp --%>
          <span class="text-sm text-blue-200 font-medium flex-shrink-0">
            {format_timestamp(@log.timestamp)}
          </span>

          <%!-- Field pills --%>
          <div class="flex items-center ml-4 gap-x-4 overflow-hidden flex-wrap gap-y-2">
            <%= for {field, enabled} <- @visible_fields, enabled do %>
              <.field_pill field={field} value={Map.get(@log, field)} />
            <% end %>
          </div>
        </div>

        <%!-- Delete button (admin only) --%>
        <%= if @is_admin do %>
          <button
            phx-click="delete_log"
            phx-value-id={@log.id}
            class="flex-shrink-0 p-1 hover:bg-gray-600 rounded transition-colors"
            data-confirm="Are you sure you want to delete this log entry?"
          >
            <.icon name="hero-trash" class="w-5 h-5 text-red-400" />
          </button>
        <% end %>
      </div>

      <%!-- Tags Row --%>
      <div class="px-4 pb-2">
        <div class="flex items-center gap-2">
          <.icon name="hero-tag" class="w-3.5 h-3.5 text-gray-500" />
          <.tag_display
            tags={@tags}
            max_visible={if @is_expanded, do: 20, else: 5}
            can_edit={@can_edit and not @log.locked}
            log_id={@log.id}
            show_all={@show_all_tags}
          />
        </div>
      </div>

      <%!-- Expanded Content --%>
      <%= if @is_expanded do %>
        <div class="p-4 border-t border-gray-700">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <%!-- Network Information --%>
            <div class="bg-gray-700/50 p-4 rounded-lg">
              <h3 class="text-sm font-medium text-white mb-3">Network Information</h3>
              <.editable_field field={:internal_ip} label="Internal IP" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:external_ip} label="External IP" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:mac_address} label="MAC Address" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:hostname} label="Hostname" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:domain} label="Domain" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
            </div>

            <%!-- Command Information --%>
            <div class="bg-gray-700/50 p-4 rounded-lg">
              <h3 class="text-sm font-medium text-white mb-3">Command Information</h3>
              <.editable_field field={:username} label="Username" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:command} label="Command" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:notes} label="Notes" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <%!-- Secrets with toggle --%>
              <div class="mb-2">
                <label class="text-xs text-blue-200 mb-1 block">Secrets</label>
                <div class="flex items-center gap-2">
                  <%= if is_editing?(@editing, @log.id, :secrets) do %>
                    <.field_editor field={:secrets} value={@editing_value} log_id={@log.id} />
                  <% else %>
                    <div
                      class={if @can_edit, do: "cursor-pointer hover:bg-gray-600/50 p-1 rounded flex-1", else: "p-1 flex-1"}
                      phx-click={if @can_edit, do: "start_edit"}
                      phx-value-field="secrets"
                      phx-value-id={@log.id}
                      phx-value-value={@log.secrets}
                    >
                      <.field_display field={:secrets} value={@log.secrets} show_secrets={@show_secrets} />
                    </div>
                  <% end %>
                  <button phx-click="toggle_secrets" phx-value-id={@log.id} class="p-1 rounded hover:bg-gray-600">
                    <%= if @show_secrets do %>
                      <.icon name="hero-eye-slash" class="w-4 h-4 text-gray-400" />
                    <% else %>
                      <.icon name="hero-eye" class="w-4 h-4 text-gray-400" />
                    <% end %>
                  </button>
                </div>
              </div>
              <%!-- Analyst (read-only) --%>
              <div class="mb-2">
                <label class="text-xs text-blue-200 mb-1 block">Analyst</label>
                <div class="p-1"><span class="text-gray-300">{@log.analyst || "-"}</span></div>
              </div>
            </div>

            <%!-- File & Status Information --%>
            <div class="bg-gray-700/50 p-4 rounded-lg">
              <h3 class="text-sm font-medium text-white mb-3">File & Status Information</h3>
              <.editable_field field={:filename} label="Filename" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:hash_algorithm} label="Hash Algorithm" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:hash_value} label="Hash Value" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:pid} label="PID" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
              <.editable_field field={:status} label="Status" log={@log} editing={@editing} editing_value={@editing_value} can_edit={@can_edit} />
            </div>
          </div>

          <%!-- Actions row --%>
          <div class="flex items-center gap-2 mt-2">
            <button phx-click="save_as_template" phx-value-id={@log.id} class="text-xs px-3 py-1 bg-gray-700 text-gray-300 rounded hover:bg-gray-600">
              Save as Template
            </button>
          </div>
        </div>

        <%!-- Evidence Panel --%>
        <%= if @show_evidence do %>
          <div class="mx-4 mb-4 mt-4 pt-4 border-t border-gray-700">
            <.live_component
              module={CloWeb.Components.EvidencePanelComponent}
              id={"evidence-#{@log.id}"}
              log_id={@log.id}
              current_user={@current_user}
              is_admin={@is_admin}
            />
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp editable_field(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="text-xs text-blue-200 mb-1 block">{@label}</label>
      <%= if is_editing?(@editing, @log.id, @field) do %>
        <.field_editor field={@field} value={@editing_value} log_id={@log.id} />
      <% else %>
        <div
          class={if @can_edit, do: "cursor-pointer hover:bg-gray-600/50 p-1 rounded", else: "p-1"}
          phx-click={if @can_edit, do: "start_edit"}
          phx-value-field={@field}
          phx-value-id={@log.id}
          phx-value-value={Map.get(@log, @field)}
        >
          <.field_display field={@field} value={Map.get(@log, @field)} />
        </div>
      <% end %>
    </div>
    """
  end

  defp table_view(assigns) do
    ~H"""
    <div class="overflow-x-auto bg-gray-800 rounded-lg">
      <table class="w-full text-sm text-left">
        <thead class="text-xs text-gray-400 uppercase bg-gray-700">
          <tr>
            <th class="px-4 py-3">Timestamp</th>
            <th class="px-4 py-3">Hostname</th>
            <th class="px-4 py-3">IP</th>
            <th class="px-4 py-3">Username</th>
            <th class="px-4 py-3">Command</th>
            <th class="px-4 py-3">Status</th>
            <th class="px-4 py-3">Analyst</th>
          </tr>
        </thead>
        <tbody>
          <%= for log <- @logs do %>
            <tr class={"border-b border-gray-700 #{if log.locked, do: "bg-gray-900", else: "hover:bg-gray-700"}"}>
              <td class="px-4 py-3 text-blue-200 text-xs">{format_timestamp(log.timestamp)}</td>
              <td class="px-4 py-3 text-white">{log.hostname || "-"}</td>
              <td class="px-4 py-3 text-blue-300">{log.internal_ip || "-"}</td>
              <td class="px-4 py-3 text-green-300">{log.username || "-"}</td>
              <td class="px-4 py-3 text-yellow-300 max-w-xs truncate">{log.command || "-"}</td>
              <td class="px-4 py-3">
                <%= if log.status do %>
                  <.status_badge status={log.status} />
                <% else %>
                  <span class="text-gray-500">-</span>
                <% end %>
              </td>
              <td class="px-4 py-3 text-gray-300">{log.analyst || "-"}</td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp nav_btn_class(true), do: "px-4 py-2 rounded-md bg-blue-600 text-white transition-colors"
  defp nav_btn_class(false), do: "px-4 py-2 rounded-md bg-gray-700 text-white hover:bg-gray-600 transition-colors"
end
