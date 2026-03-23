defmodule CloWeb.Live.Admin.EvidenceFileLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Clio.Evidence.EvidenceFile,
      repo: Clio.Repo,
      update_changeset: &CloWeb.Live.Admin.EvidenceFileLive.changeset/3,
      create_changeset: &CloWeb.Live.Admin.EvidenceFileLive.changeset/3
    ],
    layout: {CloWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def singular_name, do: "Evidence File"

  @impl Backpex.LiveResource
  def plural_name, do: "Evidence Files"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{module: Backpex.Fields.Number, label: "ID", except: [:new, :edit]},
      # NOTE: BelongsTo field — see Backpex docs for Backpex.Fields.BelongsTo configuration
      log_id: %{module: Backpex.Fields.Number, label: "Log ID"},
      filename: %{module: Backpex.Fields.Text, label: "Filename"},
      original_filename: %{module: Backpex.Fields.Text, label: "Original Filename"},
      file_type: %{module: Backpex.Fields.Text, label: "File Type"},
      file_size: %{module: Backpex.Fields.Number, label: "File Size (bytes)"},
      upload_date: %{module: Backpex.Fields.DateTime, label: "Upload Date"},
      uploaded_by: %{module: Backpex.Fields.Text, label: "Uploaded By"},
      description: %{module: Backpex.Fields.Text, label: "Description"},
      md5_hash: %{module: Backpex.Fields.Text, label: "MD5 Hash", except: [:new, :edit]},
      filepath: %{module: Backpex.Fields.Text, label: "Filepath"},
      # NOTE: Map fields may need a custom Backpex field renderer for complex display
      inserted_at: %{module: Backpex.Fields.DateTime, label: "Created At", except: [:new, :edit]},
      updated_at: %{module: Backpex.Fields.DateTime, label: "Updated At", except: [:new, :edit]}
    ]
  end

  def changeset(evidence, attrs, _meta), do: Clio.Evidence.EvidenceFile.changeset(evidence, attrs)
end
