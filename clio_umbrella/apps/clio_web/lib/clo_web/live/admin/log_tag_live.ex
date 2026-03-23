defmodule CloWeb.Live.Admin.LogTagLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Tags.LogTag,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.LogTagLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.LogTagLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Log Tag"

  @impl Backpex.LiveResource
  def plural_name, do: "Log Tags"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      # NOTE: BelongsTo fields require Backpex.Fields.BelongsTo — see Backpex docs for association config
      log_id: %{module: Backpex.Fields.Number, label: "Log ID"},
      tag_id: %{module: Backpex.Fields.Number, label: "Tag ID"},
      tagged_by: %{module: Backpex.Fields.Text, label: "Tagged By"},
      tagged_at: %{module: Backpex.Fields.DateTime, label: "Tagged At"}
    ]
  end

  def changeset(log_tag, attrs, _meta), do: Clio.Tags.LogTag.changeset(log_tag, attrs)
end
