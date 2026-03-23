defmodule CloWeb.Live.Admin.LogLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Logs.Log,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.LogLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.LogLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Log"

  @impl Backpex.LiveResource
  def plural_name, do: "Logs"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      timestamp: %{module: Backpex.Fields.DateTime, label: "Timestamp"},
      analyst: %{module: Backpex.Fields.Text, label: "Analyst"},
      command: %{module: Backpex.Fields.Text, label: "Command"},
      hostname: %{module: Backpex.Fields.Text, label: "Hostname"},
      domain: %{module: Backpex.Fields.Text, label: "Domain"},
      username: %{module: Backpex.Fields.Text, label: "Username"},
      internal_ip: %{module: Backpex.Fields.Text, label: "Internal IP"},
      external_ip: %{module: Backpex.Fields.Text, label: "External IP"},
      mac_address: %{module: Backpex.Fields.Text, label: "MAC Address"},
      filename: %{module: Backpex.Fields.Text, label: "Filename"},
      status: %{module: Backpex.Fields.Text, label: "Status"},
      notes: %{module: Backpex.Fields.Text, label: "Notes"},
      pid: %{module: Backpex.Fields.Text, label: "PID"},
      hash_algorithm: %{module: Backpex.Fields.Text, label: "Hash Algorithm"},
      hash_value: %{module: Backpex.Fields.Text, label: "Hash Value"},
      locked: %{module: Backpex.Fields.Boolean, label: "Locked"},
      locked_by: %{module: Backpex.Fields.Text, label: "Locked By"},
      # NOTE: secrets uses Clio.Encrypted.Binary — displayed as text but stored encrypted
      secrets: %{module: Backpex.Fields.Text, label: "Secrets"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(log, attrs, _meta), do: Clio.Logs.Log.changeset(log, attrs)
end
