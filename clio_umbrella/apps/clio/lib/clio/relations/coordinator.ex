defmodule Clio.Relations.Coordinator do
  @moduledoc "GenServer that coordinates relation discovery and updates."
  use GenServer

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Relations.{Relation, TagRelationship}
  alias Clio.Tags.LogTag

  @analysis_interval :timer.minutes(15)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trigger_analysis do
    GenServer.cast(__MODULE__, :analyze)
  end

  @impl true
  def init(_opts) do
    schedule_analysis()
    {:ok, %{last_run: nil}}
  end

  @impl true
  def handle_cast(:analyze, state) do
    run_analysis()
    {:noreply, %{state | last_run: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:scheduled_analysis, state) do
    run_analysis()
    schedule_analysis()
    {:noreply, %{state | last_run: DateTime.utc_now()}}
  end

  defp run_analysis do
    analyze_tag_cooccurrences()
  rescue
    e -> require Logger; Logger.error("Relation analysis failed: #{inspect(e)}")
  end

  defp analyze_tag_cooccurrences do
    # Find tags that appear together on the same logs
    pairs =
      from(lt1 in LogTag,
        join: lt2 in LogTag,
        on: lt1.log_id == lt2.log_id and lt1.tag_id < lt2.tag_id,
        group_by: [lt1.tag_id, lt2.tag_id],
        select: %{
          source_tag_id: lt1.tag_id,
          target_tag_id: lt2.tag_id,
          count: count(lt1.id)
        }
      )
      |> Repo.all()

    now = DateTime.utc_now()

    for pair <- pairs do
      case Repo.get_by(TagRelationship, source_tag_id: pair.source_tag_id, target_tag_id: pair.target_tag_id) do
        nil ->
          %TagRelationship{}
          |> TagRelationship.changeset(%{
            source_tag_id: pair.source_tag_id,
            target_tag_id: pair.target_tag_id,
            cooccurrence_count: pair.count,
            first_seen: now,
            last_seen: now
          })
          |> Repo.insert(on_conflict: :nothing)

        existing ->
          existing
          |> Ecto.Changeset.change(%{
            cooccurrence_count: pair.count,
            last_seen: now
          })
          |> Repo.update()
      end
    end
  end

  defp schedule_analysis do
    Process.send_after(self(), :scheduled_analysis, @analysis_interval)
  end
end
