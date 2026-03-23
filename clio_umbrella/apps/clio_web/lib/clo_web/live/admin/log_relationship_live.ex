defmodule CloWeb.Live.Admin.LogRelationshipLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Relations.LogRelationship,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.LogRelationshipLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.LogRelationshipLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Log Relationship"

  @impl Backpex.LiveResource
  def plural_name, do: "Log Relationships"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      # NOTE: BelongsTo fields — see Backpex docs for Backpex.Fields.BelongsTo configuration
      source_id: %{module: Backpex.Fields.Number, label: "Source Log ID"},
      target_id: %{module: Backpex.Fields.Number, label: "Target Log ID"},
      type: %{
        module: Backpex.Fields.Select,
        label: "Type",
        options: [
          "Parent-Child": "parent_child",
          Linked: "linked",
          Dependency: "dependency",
          Correlation: "correlation"
        ]
      },
      relationship: %{module: Backpex.Fields.Text, label: "Relationship"},
      created_by: %{module: Backpex.Fields.Text, label: "Created By"},
      notes: %{module: Backpex.Fields.Text, label: "Notes"},
      created_at: %{module: Backpex.Fields.DateTime, label: "Created At"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Record Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(lr, attrs, _meta), do: Clio.Relations.LogRelationship.changeset(lr, attrs)
end
