defmodule D9s.Deployments do
  @moduledoc """
  The Deployments context.
  """

  alias D9s.Deployments.Deployment

  ## Deployments

  @doc """
  Returns the list of deployments.
  """
  @spec list_deployments() :: [Deployment.t()]
  def list_deployments do
    raise "Not implemented"
  end

  @doc """
  Returns the list of deployments for a release.
  """
  @spec list_deployments_for_release(integer()) :: [Deployment.t()]
  def list_deployments_for_release(_release_id) do
    raise "Not implemented"
  end

  @doc """
  Returns the list of deployments for a destination.
  """
  @spec list_deployments_for_destination(integer()) :: [Deployment.t()]
  def list_deployments_for_destination(_destination_id) do
    raise "Not implemented"
  end

  @doc """
  Gets a single deployment.

  Raises `Ecto.NoResultsError` if the Deployment does not exist.
  """
  @spec get_deployment!(integer()) :: Deployment.t()
  def get_deployment!(_id), do: raise("Not implemented")

  @doc """
  Gets a single deployment.

  Returns `nil` if the Deployment does not exist.
  """
  @spec get_deployment(integer()) :: Deployment.t() | nil
  def get_deployment(_id), do: raise("Not implemented")

  @doc """
  Creates a deployment.
  """
  @spec create_deployment(map()) :: {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def create_deployment(_attrs \\ %{}) do
    raise "Not implemented"
  end

  @doc """
  Updates a deployment.
  """
  @spec update_deployment(Deployment.t(), map()) ::
          {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def update_deployment(_deployment, _attrs) do
    raise "Not implemented"
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking deployment changes.
  """
  @spec change_deployment(Deployment.t(), map()) :: Ecto.Changeset.t()
  def change_deployment(_deployment, _attrs \\ %{}) do
    raise "Not implemented"
  end

  ## Business Logic

  @doc """
  Deploys a release to a destination.
  """
  @spec deploy_release(integer(), integer()) :: {:ok, Deployment.t()} | {:error, term()}
  def deploy_release(_release_id, _destination_id) do
    raise "Not implemented"
  end

  @doc """
  Rolls back a deployment.
  """
  @spec rollback_deployment(integer()) :: {:ok, Deployment.t()} | {:error, term()}
  def rollback_deployment(_deployment_id) do
    raise "Not implemented"
  end

  @doc """
  Cancels a deployment.
  """
  @spec cancel_deployment(integer()) :: {:ok, Deployment.t()} | {:error, term()}
  def cancel_deployment(_deployment_id) do
    raise "Not implemented"
  end
end
