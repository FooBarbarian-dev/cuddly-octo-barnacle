defmodule CloWeb.Live.Admin.OperationLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Operations.Operation,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.OperationLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.OperationLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Operation"

  @impl Backpex.LiveResource
  def plural_name, do: "Operations"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      name: %{module: Backpex.Fields.Text, label: "Name"},
      description: %{module: Backpex.Fields.Text, label: "Description"},
      # NOTE: BelongsTo field — see Backpex docs for Backpex.Fields.BelongsTo configuration
      tag_id: %{module: Backpex.Fields.Number, label: "Tag ID"},
      is_active: %{module: Backpex.Fields.Boolean, label: "Active"},
      created_by: %{module: Backpex.Fields.Text, label: "Created By"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(operation, attrs, _meta), do: Clio.Operations.Operation.changeset(operation, attrs)
end
