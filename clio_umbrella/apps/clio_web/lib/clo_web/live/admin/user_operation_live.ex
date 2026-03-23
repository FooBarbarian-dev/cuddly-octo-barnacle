defmodule CloWeb.Live.Admin.UserOperationLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Operations.UserOperation,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.UserOperationLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.UserOperationLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "User Operation"

  @impl Backpex.LiveResource
  def plural_name, do: "User Operations"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      username: %{module: Backpex.Fields.Text, label: "Username"},
      # NOTE: BelongsTo field — see Backpex docs for Backpex.Fields.BelongsTo configuration
      operation_id: %{module: Backpex.Fields.Number, label: "Operation ID"},
      is_primary: %{module: Backpex.Fields.Boolean, label: "Primary"},
      assigned_by: %{module: Backpex.Fields.Text, label: "Assigned By"},
      assigned_at: %{module: Backpex.Fields.DateTime, label: "Assigned At"},
      last_accessed: %{module: Backpex.Fields.DateTime, label: "Last Accessed"}
    ]
  end

  def changeset(user_op, attrs, _meta), do: Clio.Operations.UserOperation.changeset(user_op, attrs)
end
