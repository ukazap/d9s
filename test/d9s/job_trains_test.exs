defmodule D9s.JobTrainsTest do
  use D9s.DataCase, async: true
  use Oban.Testing, repo: D9s.Repo

  alias D9s.JobTrains
  alias D9s.JobTrains.{LocomotiveJob, TrainJob}

  defmodule TestWorker do
    use D9s.JobTrains.Worker, queue: :default

    @impl D9s.JobTrains.Worker
    def perform_in_train(%Oban.Job{args: args}) do
      send(self(), {:job_performed, args})
      :ok
    end
  end

  describe "insert/2" do
    test "creates first job as locomotive" do
      changeset = TestWorker.new(%{id: 1})

      assert {:ok, job} = JobTrains.insert(changeset, "train_1")
      assert job.state == "available"
      assert job.meta["train_id"] == "train_1"

      # Locomotive exists
      assert Repo.get_by(LocomotiveJob, train_id: "train_1")

      # TrainJob exists
      assert Repo.get_by(TrainJob, train_id: "train_1", oban_job_id: job.id)
    end

    test "subsequent jobs wait in queue" do
      # First job becomes locomotive
      changeset1 = TestWorker.new(%{id: 1})
      {:ok, job1} = JobTrains.insert(changeset1, "train_1")

      # Second job waits
      changeset2 = TestWorker.new(%{id: 2})
      {:ok, job2} = JobTrains.insert(changeset2, "train_1")

      assert job1.state == "available"
      assert job2.state == "unavailable"

      # Only one locomotive
      locomotives = Repo.all(from l in LocomotiveJob, where: l.train_id == "train_1")
      assert length(locomotives) == 1
      assert hd(locomotives).oban_job_id == job1.id
    end

    test "different trains don't interfere" do
      changeset1 = TestWorker.new(%{id: 1})
      changeset2 = TestWorker.new(%{id: 2})

      {:ok, job1} = JobTrains.insert(changeset1, "train_1")
      {:ok, job2} = JobTrains.insert(changeset2, "train_2")

      assert job1.state == "available"
      assert job2.state == "available"

      assert Repo.get_by(LocomotiveJob, train_id: "train_1")
      assert Repo.get_by(LocomotiveJob, train_id: "train_2")
    end
  end

  describe "job execution and advancement" do
    test "executing job advances to next in queue" do
      # Queue two jobs
      changeset1 = TestWorker.new(%{id: 1})
      changeset2 = TestWorker.new(%{id: 2})

      {:ok, job1} = JobTrains.insert(changeset1, "train_1")
      {:ok, job2} = JobTrains.insert(changeset2, "train_1")

      # Execute first job
      assert :ok = TestWorker.perform(job1)

      # Second job becomes locomotive
      job2_updated = Repo.get(Oban.Job, job2.id)
      assert job2_updated.state == "available"

      locomotive = Repo.get_by(LocomotiveJob, train_id: "train_1")
      assert locomotive.oban_job_id == job2.id

      # First job's TrainJob deleted
      refute Repo.get_by(TrainJob, oban_job_id: job1.id)
      assert Repo.get_by(TrainJob, oban_job_id: job2.id)
    end

    test "last job execution clears locomotive" do
      changeset = TestWorker.new(%{id: 1})
      {:ok, job} = JobTrains.insert(changeset, "train_1")

      assert :ok = TestWorker.perform(job)

      refute Repo.get_by(LocomotiveJob, train_id: "train_1")
      refute Repo.get_by(TrainJob, oban_job_id: job.id)
    end
  end

  describe "cleanup worker" do
    test "advances on cancelled jobs with :advance config" do
      # Create two jobs in train
      changeset1 = TestWorker.new(%{id: 1})
      changeset2 = TestWorker.new(%{id: 2})

      {:ok, job1} = JobTrains.insert(changeset1, "train_1")
      {:ok, job2} = JobTrains.insert(changeset2, "train_1")

      # Cancel locomotive job
      Oban.cancel_job(job1.id)

      # Run cleanup
      D9s.JobTrains.CleanupPlugin.cleanup_now()

      # Second job becomes locomotive
      job2_updated = Repo.get(Oban.Job, job2.id)
      assert job2_updated.state == "available"

      locomotive = Repo.get_by(LocomotiveJob, train_id: "train_1")
      assert locomotive.oban_job_id == job2.id
    end

    test "cleans orphaned train jobs" do
      changeset = TestWorker.new(%{id: 1})
      {:ok, job} = JobTrains.insert(changeset, "train_1")

      # Delete Oban job directly (simulates external cleanup)
      Repo.delete_all(from j in Oban.Job, where: j.id == ^job.id)

      # TrainJob becomes orphaned
      assert Repo.get_by(TrainJob, oban_job_id: job.id)

      # Run cleanup
      D9s.JobTrains.CleanupPlugin.cleanup_now()

      # Orphaned TrainJob deleted
      refute Repo.get_by(TrainJob, oban_job_id: job.id)
    end
  end
end
