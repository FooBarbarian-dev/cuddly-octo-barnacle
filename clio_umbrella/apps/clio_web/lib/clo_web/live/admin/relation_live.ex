defmodule CloWeb.Live.Admin.RelationLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Relations.Relation,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.RelationLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.RelationLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Relation"

  @impl Backpex.LiveResource
  def plural_name, do: "Relations"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      source_type: %{module: Backpex.Fields.Text, label: "Source Type"},
      source_value: %{module: Backpex.Fields.Text, label: "Source Value"},
      target_type: %{module: Backpex.Fields.Text, label: "Target Type"},
      target_value: %{module: Backpex.Fields.Text, label: "Target Value"},
      strength: %{module: Backpex.Fields.Number, label: "Strength"},
      connection_count: %{module: Backpex.Fields.Number, label: "Connection Count"},
      pattern_type: %{
        module: Backpex.Fields.Select,
        label: "Pattern Type",
        options: [
          "Command Sequence": "command_sequence",
          "Command Co-occurrence": "command_cooccurrence",
          "User Pattern": "user_pattern",
          "Host Pattern": "host_pattern",
          "Tag Co-occurrence": "tag_cooccurrence",
          "Tag Sequence": "tag_sequence"
        ]
      },
      first_seen: %{module: Backpex.Fields.DateTime, label: "First Seen"},
      last_seen: %{module: Backpex.Fields.DateTime, label: "Last Seen"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(relation, attrs, _meta), do: Clio.Relations.Relation.changeset(relation, attrs)
end
