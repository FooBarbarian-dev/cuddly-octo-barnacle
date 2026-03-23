defmodule CloWeb.Live.Admin.ApiKeyLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.ApiKeys.ApiKey,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.ApiKeyLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.ApiKeyLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "API Key"

  @impl Backpex.LiveResource
  def plural_name, do: "API Keys"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      name: %{module: Backpex.Fields.Text, label: "Name"},
      key_id: %{module: Backpex.Fields.Text, label: "Key ID", except: [:edit]},
      key_hash: %{module: Backpex.Fields.Text, label: "Key Hash", except: [:new, :edit, :index]},
      created_by: %{module: Backpex.Fields.Text, label: "Created By"},
      description: %{module: Backpex.Fields.Text, label: "Description"},
      is_active: %{module: Backpex.Fields.Boolean, label: "Active"},
      expires_at: %{module: Backpex.Fields.DateTime, label: "Expires At"},
      last_used: %{module: Backpex.Fields.DateTime, label: "Last Used", except: [:new, :edit]},
      # NOTE: BelongsTo field — see Backpex docs for Backpex.Fields.BelongsTo configuration
      operation_id: %{module: Backpex.Fields.Number, label: "Operation ID"},
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(api_key, attrs, _meta), do: Clio.ApiKeys.ApiKey.changeset(api_key, attrs)
end
