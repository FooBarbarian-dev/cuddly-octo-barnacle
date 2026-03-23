defmodule CloWeb.Live.Admin.LogTemplateLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Templates.LogTemplate,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.LogTemplateLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.LogTemplateLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Log Template"

  @impl Backpex.LiveResource
  def plural_name, do: "Log Templates"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      name: %{module: Backpex.Fields.Text, label: "Name"},
      created_by: %{module: Backpex.Fields.Text, label: "Created By"},
      # NOTE: template_data is a :map field — may need a custom field for rich editing
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(template, attrs, _meta), do: Clio.Templates.LogTemplate.changeset(template, attrs)
end
