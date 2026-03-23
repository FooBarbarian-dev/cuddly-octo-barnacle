defmodule Clio.Evidence do
  @moduledoc "Evidence context: upload, list, download, delete evidence files for logs."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Evidence.EvidenceFile

  @upload_dir Application.compile_env(:clio, :evidence_upload_dir, "priv/uploads/evidence")

  def list_for_log(log_id) do
    from(e in EvidenceFile, where: e.log_id == ^log_id, order_by: [desc: e.upload_date])
    |> Repo.all()
  end

  def get(id) do
    case Repo.get(EvidenceFile, id) do
      nil -> {:error, :not_found}
      file -> {:ok, file}
    end
  end

  def upload(log_id, %{path: path, filename: original_filename, content_type: content_type}, uploaded_by) do
    file_size = File.stat!(path).size
    md5_hash = :crypto.hash(:md5, File.read!(path)) |> Base.encode16(case: :lower)
    stored_filename = "#{System.unique_integer([:positive])}_#{original_filename}"
    dest_dir = Path.join(@upload_dir, to_string(log_id))
    File.mkdir_p!(dest_dir)
    dest_path = Path.join(dest_dir, stored_filename)
    File.cp!(path, dest_path)

    attrs = %{
      log_id: log_id,
      filename: stored_filename,
      original_filename: original_filename,
      file_type: content_type,
      file_size: file_size,
      uploaded_by: uploaded_by,
      md5_hash: md5_hash,
      filepath: dest_path
    }

    %EvidenceFile{}
    |> EvidenceFile.changeset(attrs)
    |> Repo.insert()
  end

  def delete(id, _user) do
    with {:ok, file} <- get(id) do
      File.rm(file.filepath)
      Repo.delete(file)
    end
  end

  def update_metadata(id, attrs, _user) do
    with {:ok, file} <- get(id) do
      file
      |> EvidenceFile.changeset(attrs)
      |> Repo.update()
    end
  end
end
