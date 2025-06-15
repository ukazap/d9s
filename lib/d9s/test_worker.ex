defmodule D9s.TestWorker do
  use D9s.JobTrains.Worker, queue: :default

  @impl D9s.JobTrains.Worker
  def perform_in_train(%{args: %{"message" => message}}) do
    :timer.sleep(:timer.seconds(10))
    IO.puts("Processing: #{message}")
    :ok
  end
end
