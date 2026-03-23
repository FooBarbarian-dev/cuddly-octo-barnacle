defmodule CloWeb.Live.Admin.FileStatusHistoryLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Relations.FileStatusHistory,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.FileStatusHistoryLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.FileStatusHistoryLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "File Status History"

  @impl Backpex.LiveResource
  def plural_name, do: "File Status History"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      filename: %{module: Backpex.Fields.Text, label: "Filename"},
      status: %{module: Backpex.Fields.Text, label: "Status"},
      previous_status: %{module: Backpex.Fields.Text, label: "Previous Status"},
      hash_algorithm: %{module: Backpex.Fields.Text, label: "Hash Algorithm"},
      hash_value: %{module: Backpex.Fields.Text, label: "Hash Value"},
      hostname: %{module: Backpex.Fields.Text, label: "Hostname"},
      internal_ip: %{module: Backpex.Fields.Text, label: "Internal IP"},
      external_ip: %{module: Backpex.Fields.Text, label: "External IP"},
      mac_address: %{module: Backpex.Fields.Text, label: "MAC Address"},
      username: %{module: Backpex.Fields.Text, label: "Username"},
      analyst: %{module: Backpex.Fields.Text, label: "Analyst"},
      notes: %{module: Backpex.Fields.Text, label: "Notes"},
      command: %{module: Backpex.Fields.Text, label: "Command"},
      secrets: %{module: Backpex.Fields.Text, label: "Secrets"},
      timestamp: %{module: Backpex.Fields.DateTime, label: "Timestamp"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(fsh, attrs, _meta), do: Clio.Relations.FileStatusHistory.changeset(fsh, attrs)
end
