defmodule CloWeb.Live.Admin.TagRelationshipLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Relations.TagRelationship,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.TagRelationshipLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.TagRelationshipLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Tag Relationship"

  @impl Backpex.LiveResource
  def plural_name, do: "Tag Relationships"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      # NOTE: BelongsTo fields — see Backpex docs for Backpex.Fields.BelongsTo configuration
      source_tag_id: %{module: Backpex.Fields.Number, label: "Source Tag ID"},
      target_tag_id: %{module: Backpex.Fields.Number, label: "Target Tag ID"},
      cooccurrence_count: %{module: Backpex.Fields.Number, label: "Co-occurrence Count"},
      sequence_count: %{module: Backpex.Fields.Number, label: "Sequence Count"},
      correlation_strength: %{module: Backpex.Fields.Number, label: "Correlation Strength"},
      first_seen: %{module: Backpex.Fields.DateTime, label: "First Seen"},
      last_seen: %{module: Backpex.Fields.DateTime, label: "Last Seen"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(tr, attrs, _meta), do: Clio.Relations.TagRelationship.changeset(tr, attrs)
end
