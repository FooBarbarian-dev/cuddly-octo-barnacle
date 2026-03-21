defmodule CloWeb.EvidenceController do
  use CloWeb, :controller

  alias Clio.Repo
  alias Clio.Evidence.EvidenceFile
  import Ecto.Query

  @upload_dir "uploads/evidence"

  def index(conn, %{"log_id" => log_id}) do
    files = Repo.all(from e in EvidenceFile, where: e.log_id == ^log_id, order_by: [desc: e.upload_date])
    json(conn, %{data: Enum.map(files, &serialize/1)})
  end

  def upload(conn, %{"log_id" => log_id, "file" => upload}) do
    user = conn.assigns.current_user
    upload_dir = Path.join(Application.get_env(:clio, :data_dir, "data"), @upload_dir)
    File.mkdir_p!(upload_dir)

    filename = "#{:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)}_#{upload.filename}"
    filepath = Path.join(upload_dir, filename)
    File.cp!(upload.path, filepath)

    md5 = File.read!(filepath) |> then(&:crypto.hash(:md5, &1)) |> Base.encode16(case: :lower)
    file_size = File.stat!(filepath).size

    attrs = %{
      log_id: log_id,
      filename: filename,
      original_filename: upload.filename,
      file_type: upload.content_type,
      file_size: file_size,
      uploaded_by: user.username,
      md5_hash: md5,
      filepath: filepath
    }

    case %EvidenceFile{} |> EvidenceFile.changeset(attrs) |> Repo.insert() do
      {:ok, evidence} ->
        conn |> put_status(201) |> json(%{data: serialize(evidence)})

      {:error, changeset} ->
        File.rm(filepath)
        conn |> put_status(422) |> json(%{error: format_errors(changeset)})
    end
  end

  def download(conn, %{"id" => id}) do
    case Repo.get(EvidenceFile, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "File not found"})

      evidence ->
        if File.exists?(evidence.filepath) do
          conn
          |> put_resp_content_type(evidence.file_type || "application/octet-stream")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{evidence.original_filename}\"")
          |> send_file(200, evidence.filepath)
        else
          conn |> put_status(404) |> json(%{error: "File not found on disk"})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(EvidenceFile, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "File not found"})

      evidence ->
        File.rm(evidence.filepath)
        Repo.delete!(evidence)
        json(conn, %{message: "Evidence file deleted"})
    end
  end

  defp serialize(evidence) do
    %{
      id: evidence.id,
      log_id: evidence.log_id,
      filename: evidence.original_filename,
      file_type: evidence.file_type,
      file_size: evidence.file_size,
      uploaded_by: evidence.uploaded_by,
      description: evidence.description,
      md5_hash: evidence.md5_hash,
      upload_date: evidence.upload_date
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
