defmodule CloWeb.Components.EvidencePanelComponent do
  @moduledoc "LiveComponent for the evidence upload and display panel."
  use CloWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:evidence_files, [])
     |> allow_upload(:evidence,
       accept: ~w(.jpg .jpeg .png .gif .pdf .txt .bin .pcap),
       max_entries: 5,
       max_file_size: 10_485_760
     )}
  end

  @impl true
  def update(assigns, socket) do
    files = Clio.Evidence.list_for_log(assigns.log_id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:evidence_files, files)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload", _params, socket) do
    log_id = socket.assigns.log_id
    user = socket.assigns.current_user

    uploaded_files =
      consume_uploaded_entries(socket, :evidence, fn %{path: path}, entry ->
        result = Clio.Evidence.upload(
          log_id,
          %{path: path, filename: entry.client_name, content_type: entry.client_type},
          user.username
        )
        {:ok, result}
      end)

    files = Clio.Evidence.list_for_log(log_id)
    {:noreply, assign(socket, evidence_files: files)}
  end

  def handle_event("delete_evidence", %{"id" => id}, socket) do
    Clio.Evidence.delete(String.to_integer(id), socket.assigns.current_user)
    files = Clio.Evidence.list_for_log(socket.assigns.log_id)
    {:noreply, assign(socket, evidence_files: files)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-2 mb-4">
        <.icon name="hero-document-text" class="w-6 h-6 text-blue-400" />
        <h3 class="text-xl font-bold text-white">Evidence</h3>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Upload Area --%>
        <div>
          <form phx-submit="upload" phx-change="validate" phx-target={@myself}>
            <div
              phx-drop-target={@uploads.evidence.ref}
              phx-hook="DropZone"
              id={"drop-zone-#{@log_id}"}
              class="border-2 border-dashed border-gray-600 rounded-lg p-6 text-center hover:border-gray-500 transition-colors"
            >
              <.icon name="hero-arrow-up-tray" class="w-8 h-8 text-gray-400 mx-auto mb-2" />
              <p class="text-gray-400 text-sm mb-2">Drag & drop files here</p>
              <.live_file_input upload={@uploads.evidence} class="text-sm text-gray-400" />
            </div>

            <%= for entry <- @uploads.evidence.entries do %>
              <div class="flex items-center justify-between mt-2 bg-gray-700 rounded px-3 py-2">
                <span class="text-sm text-white truncate">{entry.client_name}</span>
                <span class="text-xs text-gray-400">{entry.progress}%</span>
              </div>
            <% end %>

            <%= if length(@uploads.evidence.entries) > 0 do %>
              <button type="submit" class="mt-3 w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700">
                Upload
              </button>
            <% end %>
          </form>
        </div>

        <%!-- Evidence List --%>
        <div class="lg:col-span-2">
          <%= if Enum.empty?(@evidence_files) do %>
            <p class="text-gray-500 text-sm">No evidence files uploaded yet.</p>
          <% else %>
            <div class="space-y-3">
              <%= for file <- @evidence_files do %>
                <div class="bg-gray-700 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-white font-medium">{file.original_filename}</span>
                    <div class="flex items-center gap-2">
                      <a
                        href={"/api/evidence/#{file.id}/download"}
                        class="text-blue-400 hover:text-blue-300 text-sm"
                        target="_blank"
                      >
                        Download
                      </a>
                      <%= if @is_admin do %>
                        <button
                          phx-click="delete_evidence"
                          phx-value-id={file.id}
                          phx-target={@myself}
                          class="text-red-400 hover:text-red-300 text-sm"
                          data-confirm="Delete this evidence file?"
                        >
                          Delete
                        </button>
                      <% end %>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2 text-xs text-gray-400">
                    <span>Type: {file.file_type}</span>
                    <span>Size: {format_file_size(file.file_size)}</span>
                    <span>Uploaded: {format_date(file.upload_date)}</span>
                    <span>By: {file.uploaded_by}</span>
                    <span class="col-span-2">MD5: {file.md5_hash}</span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_file_size(nil), do: "-"
  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_date(nil), do: "-"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_date(other), do: to_string(other)
end
