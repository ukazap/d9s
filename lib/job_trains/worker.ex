defmodule JobTrains.Worker do
  @moduledoc """
  Worker macro for jobs that should execute in trains (sequentially per train_id).

  ## Usage

      defmodule MyWorker do
        use JobTrains.Worker, 
          queue: :deployments,
          on_cancelled: :hold,
          on_discarded: :advance

        def perform_in_train(%Oban.Job{args: args}) do
          # Business logic here
        end
      end
  """

  @callback perform_in_train(Oban.Job.t()) :: term()

  defmacro __using__(opts) do
    on_cancelled = Keyword.get(opts, :on_cancelled, :advance)
    on_discarded = Keyword.get(opts, :on_discarded, :advance)

    # Pass only Oban options
    oban_opts = Keyword.drop(opts, [:on_cancelled, :on_discarded])

    quote do
      use Oban.Worker, unquote(oban_opts)
      @behaviour JobTrains.Worker

      def perform(%Oban.Job{meta: %{"train_id" => train_id}, id: job_id} = job)
          when not is_nil(train_id) do
        result = perform_in_train(job)
        JobTrains.Advancement.advance(train_id, job_id)
        result
      end

      def perform(job), do: perform_in_train(job)

      def locomotive_config do
        %{on_cancelled: unquote(on_cancelled), on_discarded: unquote(on_discarded)}
      end
    end
  end
end
