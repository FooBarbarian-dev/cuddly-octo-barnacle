defmodule CloWeb.Components.OperationSwitcherComponent do
  @moduledoc "LiveComponent for the operation switcher dropdown in the header."
  use CloWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, :open, false)}
  end

  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, :open, !socket.assigns.open)}
  end

  def handle_event("select_operation", %{"id" => op_id}, socket) do
    send(self(), {:switch_operation, String.to_integer(op_id)})
    {:noreply, assign(socket, :open, false)}
  end

  def render(assigns) do
    active_name =
      case assigns.active_operation do
        %{operation: %{name: name}} -> name
        _ -> "No Operation"
      end

    assigns = assign(assigns, :active_name, active_name)

    ~H"""
    <div class="relative">
      <button
        phx-click="toggle"
        phx-target={@myself}
        class="flex items-center gap-2 px-3 py-2 bg-gray-700 rounded-md hover:bg-gray-600 transition-colors"
      >
        <.icon name="hero-briefcase" class="w-5 h-5 text-blue-400" />
        <span class="text-white text-sm">{@active_name}</span>
        <.icon name="hero-chevron-down" class="w-4 h-4 text-gray-400" />
      </button>

      <%= if @open do %>
        <div class="absolute top-full left-0 mt-2 w-64 bg-gray-800 border border-gray-700 rounded-lg shadow-xl z-[9999]">
          <div class="py-1">
            <%= for uo <- @operations do %>
              <button
                phx-click="select_operation"
                phx-value-id={uo.operation.id}
                phx-target={@myself}
                class={"w-full text-left px-4 py-2 text-sm flex items-center justify-between #{if active?(@active_operation, uo), do: "bg-blue-600 text-white", else: "text-gray-300 hover:bg-gray-700"}"}
              >
                <span>{uo.operation.name}</span>
                <%= if uo.is_primary do %>
                  <span class="text-xs bg-blue-500/30 text-blue-300 px-1.5 py-0.5 rounded">Primary</span>
                <% end %>
              </button>
            <% end %>
          </div>
          <%= if @active_operation do %>
            <div class="border-t border-gray-700 px-4 py-2">
              <span class="text-xs text-blue-400">
                Active: {active_tag_name(@active_operation)}
              </span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp active?(nil, _uo), do: false
  defp active?(%{operation: %{id: active_id}}, uo), do: uo.operation.id == active_id
  defp active?(_, _), do: false

  defp active_tag_name(%{operation: %{tag: %{name: name}}}), do: name
  defp active_tag_name(_), do: ""
end
