defmodule CloWeb.ClioComponents do
  @moduledoc "Shared function components for the Clio LiveView UI."
  use Phoenix.Component
  import Bitwise
  import CloWeb.Gettext

  # ── Navigation ──

  attr :current_user, :map, required: true
  attr :active_view, :atom, required: true

  def nav_bar(assigns) do
    ~H"""
    <div class="flex space-x-2 flex-wrap gap-y-2 mb-4">
      <.link navigate="/" class={nav_button_class(@active_view == :logs)}>
        Logs
      </.link>
      <.link navigate="/relations" class={nav_button_class(@active_view == :relations)}>
        <.icon name="hero-share" class="w-5 h-5" /> Relations
      </.link>
      <.link navigate="/file-status" class={nav_button_class(@active_view == :file_status)}>
        <.icon name="hero-document" class="w-5 h-5" /> File Status
      </.link>
      <.link navigate="/settings" class={nav_button_class(@active_view == :settings)}>
        <.icon name="hero-cog-6-tooth" class="w-5 h-5" /> Settings
      </.link>
      <%= if @current_user.role == :admin do %>
        <.link navigate="/manage/operations" class={nav_button_class(@active_view == :admin_operations)}>
          <.icon name="hero-briefcase" class="w-5 h-5" /> Operations
        </.link>
        <.link navigate="/manage/tags" class={nav_button_class(@active_view == :admin_tags)}>
          <.icon name="hero-tag" class="w-5 h-5" /> Tags
        </.link>
        <.link navigate="/manage/export" class={nav_button_class(@active_view == :admin_export)}>
          <.icon name="hero-circle-stack" class="w-5 h-5" /> Export
        </.link>
        <.link navigate="/manage/log-management" class={nav_button_class(@active_view == :admin_log_management)}>
          <.icon name="hero-server" class="w-5 h-5" /> Log Management
        </.link>
        <.link navigate="/manage/sessions" class={nav_button_class(@active_view == :admin_sessions)}>
          <.icon name="hero-users" class="w-5 h-5" /> Sessions
        </.link>
        <.link navigate="/manage/api-keys" class={nav_button_class(@active_view == :admin_api_keys)}>
          <.icon name="hero-key" class="w-5 h-5" /> API Keys
        </.link>
        <.link navigate="/manage/api-docs" class={nav_button_class(@active_view == :admin_api_docs)}>
          <.icon name="hero-book-open" class="w-5 h-5" /> API Docs
        </.link>
      <% end %>
    </div>
    """
  end

  defp nav_button_class(true),
    do: "px-4 py-2 rounded-md flex items-center gap-2 transition-colors duration-200 bg-blue-600 text-white"

  defp nav_button_class(false),
    do: "px-4 py-2 rounded-md flex items-center gap-2 transition-colors duration-200 bg-gray-700 text-white hover:bg-gray-600"

  # ── Tag Pill ──

  attr :tag, :map, required: true
  attr :show_remove, :boolean, default: false
  attr :on_remove, :string, default: nil
  attr :size, :atom, default: :xs

  def tag_pill(assigns) do
    text_color = contrast_color(assigns.tag.color || "#6B7280")
    assigns = assign(assigns, :text_color, text_color)

    ~H"""
    <span
      class="inline-flex items-center gap-1 rounded-full font-medium px-2 py-0.5 text-xs transition-all duration-200 hover:scale-105"
      style={"background-color: #{@tag.color || "#6B7280"}; color: #{@text_color}"}
    >
      <span class="truncate max-w-[120px]">{@tag.name}</span>
      <%= if @show_remove do %>
        <button
          type="button"
          phx-click={@on_remove}
          phx-value-tag-id={@tag.id}
          class="opacity-70 hover:opacity-100 ml-0.5"
        >
          <.icon name="hero-x-mark" class="w-3 h-3" />
        </button>
      <% end %>
    </span>
    """
  end

  # ── Tag Display ──

  attr :tags, :list, default: []
  attr :max_visible, :integer, default: 5
  attr :can_edit, :boolean, default: false
  attr :log_id, :integer, default: nil
  attr :show_all, :boolean, default: false

  def tag_display(assigns) do
    sorted = sort_tags(assigns.tags || [])
    visible = if assigns.show_all, do: sorted, else: Enum.take(sorted, assigns.max_visible)
    remaining = length(sorted) - length(visible)
    assigns = assign(assigns, sorted: sorted, visible: visible, remaining: remaining)

    ~H"""
    <div class="flex items-center gap-1 flex-wrap">
      <%= for tag <- @visible do %>
        <.tag_pill
          tag={tag}
          show_remove={@can_edit}
          on_remove="remove_tag"
        />
      <% end %>
      <%= if @remaining > 0 and not @show_all do %>
        <button
          type="button"
          phx-click="toggle_show_all_tags"
          phx-value-log-id={@log_id}
          class="text-xs text-gray-400 hover:text-white px-1"
        >
          +{@remaining} more
        </button>
      <% end %>
      <%= if @show_all and length(@sorted) > @max_visible do %>
        <button
          type="button"
          phx-click="toggle_show_all_tags"
          phx-value-log-id={@log_id}
          class="text-xs text-gray-400 hover:text-white px-1"
        >
          Show less
        </button>
      <% end %>
      <%= if @can_edit do %>
        <button
          type="button"
          phx-click="open_tag_modal"
          phx-value-log-id={@log_id}
          class="bg-gray-700 hover:bg-gray-600 text-gray-300 rounded-full text-xs px-2 py-0.5 inline-flex items-center gap-1"
        >
          <.icon name="hero-plus" class="w-3 h-3" /> Add Tag
        </button>
      <% end %>
    </div>
    """
  end

  # ── Pagination ──

  attr :page, :integer, required: true
  attr :per_page, :integer, required: true
  attr :total, :integer, required: true

  def pagination(assigns) do
    total_pages = max(ceil(assigns.total / assigns.per_page), 1)
    from = (assigns.page - 1) * assigns.per_page + 1
    to = min(assigns.page * assigns.per_page, assigns.total)
    assigns = assign(assigns, total_pages: total_pages, from: from, to: to)

    ~H"""
    <div class="flex flex-col sm:flex-row items-center justify-between p-2 sm:px-4 sm:py-3 bg-gray-800 border-t border-gray-700 rounded-b-lg">
      <div class="flex items-center text-sm text-gray-400">
        <span class="mr-4">Rows per page:</span>
        <select
          phx-change="change_per_page"
          name="per_page"
          class="bg-gray-700 border border-gray-600 text-white px-2 py-1 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <%= for size <- [25, 50, 100, 150, 200] do %>
            <option value={size} selected={size == @per_page}>{size}</option>
          <% end %>
        </select>
        <span class="ml-4 text-xs sm:text-sm">
          Showing {@from} - {@to} of {@total}
        </span>
      </div>
      <div class="flex items-center space-x-2 mt-2 sm:mt-0">
        <button
          phx-click="go_to_page"
          phx-value-page="1"
          disabled={@page == 1}
          class="p-1 rounded text-gray-400 hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-double-left" class="w-5 h-5" />
        </button>
        <button
          phx-click="go_to_page"
          phx-value-page={@page - 1}
          disabled={@page == 1}
          class="p-1 rounded text-gray-400 hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-left" class="w-5 h-5" />
        </button>
        <span class="text-sm text-gray-300 px-2">{@page} / {@total_pages}</span>
        <button
          phx-click="go_to_page"
          phx-value-page={@page + 1}
          disabled={@page >= @total_pages}
          class="p-1 rounded text-gray-400 hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-right" class="w-5 h-5" />
        </button>
        <button
          phx-click="go_to_page"
          phx-value-page={@total_pages}
          disabled={@page >= @total_pages}
          class="p-1 rounded text-gray-400 hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-double-right" class="w-5 h-5" />
        </button>
      </div>
    </div>
    """
  end

  # ── Search Filter ──

  attr :query, :string, default: ""
  attr :field, :string, default: "all"

  def search_filter(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <select
        name="search_field"
        phx-change="search_field_changed"
        class="bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <option value="all" selected={@field == "all"}>All Fields</option>
        <option value="hostname">Hostname</option>
        <option value="internal_ip">Internal IP</option>
        <option value="external_ip">External IP</option>
        <option value="domain">Domain</option>
        <option value="username">Username</option>
        <option value="command">Command</option>
        <option value="notes">Notes</option>
        <option value="filename">Filename</option>
        <option value="status">Status</option>
        <option value="analyst">Analyst</option>
        <option value="mac_address">MAC Address</option>
        <option value="hash_algorithm">Hash Algorithm</option>
        <option value="hash_value">Hash Value</option>
        <option value="pid">PID</option>
        <option value="secrets">Secrets</option>
      </select>
      <div class="relative flex-1">
        <.icon name="hero-magnifying-glass" class="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
        <input
          type="text"
          name="search_query"
          value={@query}
          placeholder="Search logs..."
          phx-debounce="300"
          phx-keyup="search_changed"
          class="w-full bg-gray-700 border border-gray-600 text-white pl-10 pr-10 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-400"
        />
        <%= if @query != "" do %>
          <button
            type="button"
            phx-click="clear_search"
            class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # ── Date Range Filter ──

  attr :start_date, :string, default: ""
  attr :end_date, :string, default: ""

  def date_range_filter(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <label class="text-sm text-gray-400">From:</label>
      <input
        type="datetime-local"
        name="start_date"
        value={@start_date}
        phx-change="date_range_changed"
        class="bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <label class="text-sm text-gray-400">To:</label>
      <input
        type="datetime-local"
        name="end_date"
        value={@end_date}
        phx-change="date_range_changed"
        class="bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
    </div>
    """
  end

  # ── Status Badge ──

  attr :status, :string, required: true

  def status_badge(assigns) do
    {text_class, bg_class} = status_colors(assigns.status)
    assigns = assign(assigns, text_class: text_class, bg_class: bg_class)

    ~H"""
    <span class={"#{@bg_class} #{@text_class} px-2 py-1 rounded-full text-xs font-medium"}>
      {@status}
    </span>
    """
  end

  # ── Field Display ──

  attr :field, :atom, required: true
  attr :value, :string, default: nil
  attr :show_secrets, :boolean, default: false

  def field_display(assigns) do
    ~H"""
    <div>
      <%= cond do %>
        <% @field == :secrets and not @show_secrets -> %>
          <span class="text-gray-400">••••••••••</span>
        <% @field == :status and @value -> %>
          <span class={status_text_class(@value)}>{@value}</span>
        <% @field == :timestamp and @value -> %>
          <span class="text-blue-200 font-medium text-sm">{format_timestamp(@value)}</span>
        <% @field == :mac_address and @value -> %>
          <span class="text-cyan-300">{String.upcase(@value || "")}</span>
        <% true -> %>
          <span class="text-gray-300">{@value || "-"}</span>
        <% end %>
      </div>
    """
  end

  # ── Field Editor ──

  attr :field, :atom, required: true
  attr :value, :string, default: ""
  attr :log_id, :integer, required: true

  def field_editor(assigns) do
    ~H"""
    <%= cond do %>
      <% @field in [:command, :notes] -> %>
        <textarea
          phx-hook="AutoFocus"
          id={"edit-#{@log_id}-#{@field}"}
          data-field={@field}
          phx-blur="save_edit"
          phx-keydown="handle_edit_keydown"
          phx-value-field={@field}
          phx-value-log-id={@log_id}
          name="value"
          rows="3"
          class="w-full bg-gray-600 border border-gray-500 text-white px-2 py-1 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >{@value}</textarea>
      <% @field == :hash_algorithm -> %>
        <select
          phx-hook="AutoFocus"
          id={"edit-#{@log_id}-#{@field}"}
          phx-blur="save_edit"
          phx-change="save_edit"
          phx-value-field={@field}
          phx-value-log-id={@log_id}
          name="value"
          class="w-full bg-gray-600 border border-gray-500 text-white px-2 py-1 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <%= for algo <- ~w(MD5 SHA-1 SHA-256 SHA-512 BLAKE2 RIPEMD-160 CRC32 SHA-3 Other) do %>
            <option value={algo} selected={algo == @value}>{algo}</option>
          <% end %>
        </select>
      <% @field == :status -> %>
        <select
          phx-hook="AutoFocus"
          id={"edit-#{@log_id}-#{@field}"}
          phx-blur="save_edit"
          phx-change="save_edit"
          phx-value-field={@field}
          phx-value-log-id={@log_id}
          name="value"
          class="w-full bg-gray-600 border border-gray-500 text-white px-2 py-1 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">-- Select --</option>
          <%= for status <- ~w(ON_DISK IN_MEMORY ENCRYPTED REMOVED CLEANED DORMANT DETECTED UNKNOWN) do %>
            <option value={status} selected={status == @value}>{status}</option>
          <% end %>
        </select>
      <% true -> %>
        <input
          type="text"
          phx-hook="AutoFocus"
          id={"edit-#{@log_id}-#{@field}"}
          data-field={@field}
          phx-blur="save_edit"
          phx-keydown="handle_edit_keydown"
          phx-value-field={@field}
          phx-value-log-id={@log_id}
          name="value"
          value={@value}
          class="w-full bg-gray-600 border border-gray-500 text-white px-2 py-1 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      <% end %>
    """
  end

  # ── Card Field Pill ──

  attr :field, :atom, required: true
  attr :value, :string, default: nil

  def field_pill(assigns) do
    {label, color_class} = pill_config(assigns.field)
    assigns = assign(assigns, label: label, color_class: color_class)

    ~H"""
    <%= if @value && @value != "" do %>
      <span class="bg-gray-700 rounded text-xs px-2 py-1 font-medium whitespace-nowrap">
        <%= if @label do %>
          <span class="text-gray-400">{@label}</span>
        <% end %>
        <span class={@color_class}>
          <%= if @field == :command do %>
            <span class="max-w-xs overflow-hidden text-ellipsis inline-block align-bottom">
              {truncate(@value, 60)}
            </span>
          <% else %>
            {@value}
          <% end %>
        </span>
      </span>
    <% end %>
    """
  end

  # ── Password Validation Display ──

  attr :password, :string, default: ""

  def password_rules(assigns) do
    rules = password_validation_rules(assigns.password)
    assigns = assign(assigns, :rules, rules)

    ~H"""
    <div class="space-y-1 mt-2">
      <%= for {label, passes} <- @rules do %>
        <div class="flex items-center gap-2 text-sm">
          <%= if passes do %>
            <span class="text-green-400">&#10003;</span>
          <% else %>
            <span class="text-red-400">&#10007;</span>
          <% end %>
          <span class={if passes, do: "text-green-300", else: "text-red-300"}>{label}</span>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Helpers ──

  defp contrast_color(hex) do
    hex = String.trim_leading(hex, "#")
    case Integer.parse(hex, 16) do
      {rgb, _} ->
        r = rgb |> bsr(16) |> band(0xFF)
        g = rgb |> bsr(8) |> band(0xFF)
        b = band(rgb, 0xFF)
        luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        if luminance > 0.5, do: "#1F2937", else: "#FFFFFF"
      _ -> "#FFFFFF"
    end
  end

  @tag_category_order %{
    "operation" => 0, "priority" => 1, "status" => 2, "technique" => 3,
    "tool" => 4, "target" => 5, "workflow" => 6, "evidence" => 7,
    "security" => 8, "custom" => 9
  }

  defp sort_tags(tags) do
    Enum.sort_by(tags, fn tag ->
      Map.get(@tag_category_order, tag.category || "custom", 9)
    end)
  end

  defp pill_config(:internal_ip), do: {"IP: ", "text-blue-300"}
  defp pill_config(:external_ip), do: {"Ext IP: ", "text-blue-300"}
  defp pill_config(:mac_address), do: {"MAC: ", "text-cyan-300"}
  defp pill_config(:pid), do: {"PID: ", "text-cyan-300"}
  defp pill_config(:hostname), do: {"Host: ", "text-white"}
  defp pill_config(:domain), do: {"Domain: ", "text-white"}
  defp pill_config(:username), do: {"User: ", "text-green-300"}
  defp pill_config(:filename), do: {"File: ", "text-purple-300"}
  defp pill_config(:command), do: {"Cmd: ", "text-yellow-300"}
  defp pill_config(:status), do: {nil, "font-bold"}
  defp pill_config(_), do: {nil, "text-gray-300"}

  defp status_colors("ON_DISK"), do: {"text-yellow-300", "bg-yellow-600/20"}
  defp status_colors("IN_MEMORY"), do: {"text-blue-300", "bg-blue-600/20"}
  defp status_colors("ENCRYPTED"), do: {"text-purple-300", "bg-purple-600/20"}
  defp status_colors("REMOVED"), do: {"text-red-300", "bg-red-600/20"}
  defp status_colors("CLEANED"), do: {"text-green-300", "bg-green-600/20"}
  defp status_colors("DORMANT"), do: {"text-gray-300", "bg-gray-600/20"}
  defp status_colors("DETECTED"), do: {"text-orange-300", "bg-orange-600/20"}
  defp status_colors("UNKNOWN"), do: {"text-gray-400", "bg-gray-600/20"}
  defp status_colors(_), do: {"text-gray-400", "bg-gray-600/20"}

  def status_text_class("ON_DISK"), do: "text-yellow-300"
  def status_text_class("IN_MEMORY"), do: "text-blue-300"
  def status_text_class("ENCRYPTED"), do: "text-purple-300"
  def status_text_class("REMOVED"), do: "text-red-300"
  def status_text_class("CLEANED"), do: "text-green-300"
  def status_text_class("DORMANT"), do: "text-gray-300"
  def status_text_class("DETECTED"), do: "text-orange-300"
  def status_text_class("UNKNOWN"), do: "text-gray-400"
  def status_text_class(_), do: "text-gray-400"

  def format_timestamp(nil), do: "-"
  def format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%SZ")
  end
  def format_timestamp(other), do: to_string(other)

  defp truncate(nil, _), do: ""
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."

  defp password_validation_rules(password) do
    [
      {"At least 12 characters", String.length(password) >= 12},
      {"At most 128 characters", String.length(password) <= 128},
      {"Contains uppercase letter", password =~ ~r/[A-Z]/},
      {"Contains lowercase letter", password =~ ~r/[a-z]/},
      {"Contains a digit", password =~ ~r/[0-9]/},
      {"Contains a special character", password =~ ~r/[^a-zA-Z0-9]/},
      {"No 3+ repeated characters", not (password =~ ~r/(.)\1{2,}/)},
      {"Not only letters then numbers", not (password =~ ~r/^[a-zA-Z]+[0-9]+$/)},
      {"No SQL injection patterns", not contains_sql?(password)},
      {"No XSS patterns", not contains_xss?(password)}
    ]
  end

  defp contains_sql?(pw) do
    downcased = String.downcase(pw)
    Enum.any?(~w(-- ; union select drop insert delete update alter exec execute), fn p ->
      String.contains?(downcased, p)
    end)
  end

  defp contains_xss?(pw) do
    downcased = String.downcase(pw)
    Enum.any?(["<script", "javascript:", "onerror=", "onload=", "onclick=", "eval("], fn p ->
      String.contains?(downcased, p)
    end)
  end
end
