defmodule CloWeb.Live.Admin.TagLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Tags.Tag,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.TagLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.TagLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Tag"

  @impl Backpex.LiveResource
  def plural_name, do: "Tags"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      name: %{module: Backpex.Fields.Text, label: "Name"},
      category: %{
        module: Backpex.Fields.Select,
        label: "Category",
        options: [
          Technique: "technique",
          Tool: "tool",
          Target: "target",
          Status: "status",
          Priority: "priority",
          Workflow: "workflow",
          Evidence: "evidence",
          Security: "security",
          Operation: "operation",
          Custom: "custom"
        ]
      },
      color: %{module: Backpex.Fields.Text, label: "Color"},
      description: %{module: Backpex.Fields.Text, label: "Description"},
      is_default: %{module: Backpex.Fields.Boolean, label: "Default"},
      created_by: %{module: Backpex.Fields.Text, label: "Created By"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(tag, attrs, _meta), do: Clio.Tags.Tag.changeset(tag, attrs)
end
