defmodule D9s.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      D9sWeb.Telemetry,
      D9s.Repo,
      {Ecto.Migrator, repos: Application.fetch_env!(:d9s, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:d9s, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: D9s.PubSub},
      {Task, &reset_executing_jobs/0},
      {Oban, Application.fetch_env!(:d9s, Oban)},
      D9sWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: D9s.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    D9sWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end

  defp reset_executing_jobs do
    import Ecto.Query

    D9s.Repo.update_all(
      from(j in Oban.Job, where: j.state == "executing"),
      set: [state: "available"]
    )
  end
end
