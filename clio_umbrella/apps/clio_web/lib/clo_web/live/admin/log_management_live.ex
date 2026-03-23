defmodule CloWeb.Admin.LogManagementLive do
  @moduledoc "Admin log management: log file status, rotation, archives, S3 config."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, s3_config} = Clio.Export.get_s3_config()
    {:ok, archives} = Clio.Export.list_archives()
    log_status = get_log_status()

    {:ok,
     assign(socket,
       page_title: "Log Management",
       active_view: :admin_log_management,
       log_status: log_status,
       archives: archives,
       rotating: false,
       rotation_result: nil,
       # S3 config
       s3_config: s3_config,
       show_s3_config: false,
       s3_save_result: nil
     )}
  end

  defp get_log_status do
    data_dir = Application.get_env(:clio, :data_dir, "data")

    for category <- ~w(security data system audit) do
      path = Path.join(data_dir, "#{category}_logs.json")
      stat = if File.exists?(path), do: File.stat!(path), else: nil

      entry_count =
        if File.exists?(path) do
          case File.read(path) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, entries} when is_list(entries) -> length(entries)
                _ -> 0
              end
            _ -> 0
          end
        else
          0
        end

      %{
        category: category,
        path: path,
        entry_count: entry_count,
        file_size: if(stat, do: stat.size, else: 0),
        last_modified: if(stat, do: stat.mtime, else: nil)
      }
    end
  end

  @impl true
  def handle_event("force_rotation", _params, socket) do
    socket = assign(socket, rotating: true)

    case Clio.Export.force_rotation() do
      {:ok, result} ->
        {:ok, archives} = Clio.Export.list_archives()
        {:noreply, assign(socket, rotating: false, rotation_result: result, archives: archives,
                          log_status: get_log_status())}
      {:error, reason} ->
        {:noreply, socket |> assign(rotating: false) |> put_flash(:error, "Rotation failed: #{inspect(reason)}")}
    end
  end

  def handle_event("toggle_s3_config", _params, socket) do
    {:noreply, assign(socket, show_s3_config: !socket.assigns.show_s3_config)}
  end

  def handle_event("save_s3_config", params, socket) do
    config = %{
      bucket: params["bucket"] || "",
      region: params["region"] || "",
      access_key_id: params["access_key_id"] || "",
      secret_access_key: params["secret_access_key"] || "",
      prefix: params["prefix"] || "",
      auto_export: params["auto_export"] == "true"
    }

    case Clio.Export.save_s3_config(config) do
      {:ok, config} ->
        {:noreply, assign(socket, s3_config: config, s3_save_result: "S3 configuration saved")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save S3 config")}
    end
  end

  def handle_event("upload_to_s3", %{"path" => path}, socket) do
    Clio.Export.upload_to_s3(path)
    {:noreply, put_flash(socket, :info, "S3 upload initiated")}
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
    active_op = case Clio.Operations.get_active_operation(user.username) do {:ok, op} -> op; _ -> nil end
    {:noreply, assign(socket, user_operations: operations, active_operation: active_op)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <div class="space-y-6">
        <%!-- Log File Status --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-bold text-white">Log File Status</h2>
            <button
              phx-click="force_rotation"
              class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2"
              disabled={@rotating}
            >
              <%= if @rotating do %>
                <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" /> Rotating...
              <% else %>
                <.icon name="hero-arrow-path" class="w-5 h-5" /> Force Rotation
              <% end %>
            </button>
          </div>

          <%= if @rotation_result do %>
            <div class="bg-green-900/50 border border-green-700 rounded-lg p-3 mb-4">
              <p class="text-green-300 text-sm">{@rotation_result.message}</p>
            </div>
          <% end %>

          <table class="w-full text-sm text-left">
            <thead class="text-xs text-gray-400 uppercase bg-gray-700">
              <tr>
                <th class="px-4 py-3">Category</th>
                <th class="px-4 py-3">File Path</th>
                <th class="px-4 py-3">Entries</th>
                <th class="px-4 py-3">Size</th>
              </tr>
            </thead>
            <tbody>
              <%= for log <- @log_status do %>
                <tr class="border-b border-gray-700">
                  <td class="px-4 py-3 text-white font-medium capitalize">{log.category}</td>
                  <td class="px-4 py-3 text-gray-400 font-mono text-xs">{log.path}</td>
                  <td class="px-4 py-3 text-gray-300">{log.entry_count}</td>
                  <td class="px-4 py-3 text-gray-300">{format_size(log.file_size)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <%!-- Archives --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-bold text-white mb-4">Archives</h2>
          <%= if Enum.empty?(@archives) do %>
            <p class="text-gray-500">No archives found.</p>
          <% else %>
            <div class="space-y-2">
              <%= for archive <- @archives do %>
                <div class="flex items-center justify-between bg-gray-700 rounded p-3">
                  <div>
                    <span class="text-white text-sm">{archive.filename}</span>
                    <span class="text-gray-400 text-xs ml-2">{format_size(archive.size)}</span>
                  </div>
                  <button phx-click="upload_to_s3" phx-value-path={archive.filepath}
                    class="text-blue-400 hover:text-blue-300 text-xs">Upload to S3</button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- S3 Configuration --%>
        <div class="bg-gray-800 rounded-lg shadow-lg">
          <button phx-click="toggle_s3_config"
            class="w-full px-6 py-4 flex items-center justify-between hover:bg-gray-700 rounded-lg transition-colors">
            <h2 class="text-xl font-bold text-white">S3 Configuration</h2>
            <%= if @show_s3_config do %>
              <.icon name="hero-chevron-down" class="w-5 h-5 text-gray-400" />
            <% else %>
              <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
            <% end %>
          </button>

          <%= if @show_s3_config do %>
            <div class="px-6 pb-6">
              <%= if @s3_save_result do %>
                <div class="bg-green-900/50 border border-green-700 rounded-lg p-3 mb-4">
                  <p class="text-green-300 text-sm">{@s3_save_result}</p>
                </div>
              <% end %>

              <form phx-submit="save_s3_config" class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="text-xs text-gray-400 block mb-1">Bucket Name</label>
                  <input type="text" name="bucket" value={@s3_config.bucket}
                    class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                </div>
                <div>
                  <label class="text-xs text-gray-400 block mb-1">Region</label>
                  <input type="text" name="region" value={@s3_config.region}
                    class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                </div>
                <div>
                  <label class="text-xs text-gray-400 block mb-1">Access Key ID</label>
                  <input type="text" name="access_key_id" value={@s3_config.access_key_id}
                    class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                </div>
                <div>
                  <label class="text-xs text-gray-400 block mb-1">Secret Access Key</label>
                  <input type="password" name="secret_access_key" value={@s3_config.secret_access_key}
                    class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                </div>
                <div>
                  <label class="text-xs text-gray-400 block mb-1">Prefix Path</label>
                  <input type="text" name="prefix" value={@s3_config.prefix}
                    class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                </div>
                <div class="flex items-end">
                  <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                    <input type="checkbox" name="auto_export" value="true" checked={@s3_config.auto_export}
                      class="rounded bg-gray-700 border-gray-600 text-blue-600" />
                    Auto-export on rotation
                  </label>
                </div>
                <div class="md:col-span-2">
                  <button type="submit" class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
                    Save S3 Configuration
                  </button>
                </div>
              </form>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
