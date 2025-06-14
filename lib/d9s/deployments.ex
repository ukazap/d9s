defmodule D9s.Deployments do
  @moduledoc """
  The Deployments context.

  Handles deployment orchestration and tracking across apps and infrastructure.
  """

  import Ecto.Query, warn: false
  alias D9s.Repo
  alias D9s.Deployments.Deployment

  ## Deployments

  @doc """
  Returns the list of deployments.

  ## Examples

      iex> list_deployments()
      [%Deployment{}, ...]

  """
  @spec list_deployments() :: [Deployment.t()]
  def list_deployments do
    Repo.all(Deployment)
    |> Repo.preload([:release, :destination])
  end

  @doc """
  Returns the list of deployments for a release.

  ## Examples

      iex> list_deployments_for_release(1)
      [%Deployment{release_id: 1}, ...]

  """
  @spec list_deployments_for_release(integer()) :: [Deployment.t()]
  def list_deployments_for_release(release_id) do
    Deployment
    |> where([d], d.release_id == ^release_id)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
    |> Repo.preload([:release, :destination])
  end

  @doc """
  Returns the list of deployments for a destination.

  ## Examples

      iex> list_deployments_for_destination(1)
      [%Deployment{destination_id: 1}, ...]

  """
  @spec list_deployments_for_destination(integer()) :: [Deployment.t()]
  def list_deployments_for_destination(destination_id) do
    Deployment
    |> where([d], d.destination_id == ^destination_id)
    |> order_by([d], desc: d.inserted_at)
    |> Repo.all()
    |> Repo.preload([:release, :destination])
  end

  @doc """
  Gets a single deployment.

  Raises `Ecto.NoResultsError` if the Deployment does not exist.

  ## Examples

      iex> get_deployment!(123)
      %Deployment{}

      iex> get_deployment!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_deployment!(integer()) :: Deployment.t()
  def get_deployment!(id) do
    Deployment
    |> Repo.get!(id)
    |> Repo.preload([:release, :destination])
  end

  @doc """
  Gets a single deployment.

  Returns `nil` if the Deployment does not exist.

  ## Examples

      iex> get_deployment(123)
      %Deployment{}

      iex> get_deployment(456)
      nil

  """
  @spec get_deployment(integer()) :: Deployment.t() | nil
  def get_deployment(id) do
    case Repo.get(Deployment, id) do
      nil -> nil
      deployment -> Repo.preload(deployment, [:release, :destination])
    end
  end

  @doc """
  Creates a deployment.

  ## Examples

      iex> create_deployment(%{release_id: 1, destination_id: 2})
      {:ok, %Deployment{}}

      iex> create_deployment(%{bad_field: "value"})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_deployment(map()) :: {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def create_deployment(attrs \\ %{}) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a deployment.

  ## Examples

      iex> update_deployment(deployment, %{status: "deployed"})
      {:ok, %Deployment{}}

      iex> update_deployment(deployment, %{status: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_deployment(Deployment.t(), map()) ::
          {:ok, Deployment.t()} | {:error, Ecto.Changeset.t()}
  def update_deployment(deployment, attrs) do
    deployment
    |> Deployment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking deployment changes.

  ## Examples

      iex> change_deployment(deployment)
      %Ecto.Changeset{data: %Deployment{}}

  """
  @spec change_deployment(Deployment.t(), map()) :: Ecto.Changeset.t()
  def change_deployment(deployment, attrs \\ %{}) do
    Deployment.changeset(deployment, attrs)
  end

  ## Business Logic

  @doc """
  Deploys a release to a destination.

  Creates a new deployment record and initiates the deployment process.
  The deployment will be processed asynchronously via Oban.

  ## Examples

      iex> deploy_release(1, 2)
      {:ok, %Deployment{status: "pending"}}

      iex> deploy_release(999, 2)
      {:error, :release_not_found}

  """
  @spec deploy_release(integer(), integer()) :: {:ok, Deployment.t()} | {:error, term()}
  def deploy_release(release_id, destination_id) do
    attrs = %{
      release_id: release_id,
      destination_id: destination_id,
      status: "pending",
      started_at: DateTime.utc_now()
    }

    case create_deployment(attrs) do
      {:ok, deployment} ->
        # TODO: Enqueue Oban job for actual deployment
        {:ok, deployment}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Rolls back a deployment.

  Updates the deployment status and initiates the rollback process.

  ## Examples

      iex> rollback_deployment(123)
      {:ok, %Deployment{status: "rolled_back"}}

      iex> rollback_deployment(999)
      {:error, :deployment_not_found}

  """
  @spec rollback_deployment(integer()) :: {:ok, Deployment.t()} | {:error, term()}
  def rollback_deployment(deployment_id) do
    case get_deployment(deployment_id) do
      nil ->
        {:error, :deployment_not_found}

      deployment ->
        if deployment.status == "deployed" do
          update_deployment(deployment, %{
            status: "rolled_back",
            completed_at: DateTime.utc_now()
          })
        else
          {:error, :deployment_not_deployed}
        end
    end
  end

  @doc """
  Cancels a deployment.

  Only pending or deploying deployments can be cancelled.

  ## Examples

      iex> cancel_deployment(123)
      {:ok, %Deployment{status: "failed"}}

      iex> cancel_deployment(999)
      {:error, :deployment_not_found}

  """
  @spec cancel_deployment(integer()) :: {:ok, Deployment.t()} | {:error, term()}
  def cancel_deployment(deployment_id) do
    case get_deployment(deployment_id) do
      nil ->
        {:error, :deployment_not_found}

      deployment ->
        if deployment.status in ["pending", "deploying"] do
          update_deployment(deployment, %{
            status: "failed",
            completed_at: DateTime.utc_now(),
            error_message: "Deployment cancelled by user"
          })
        else
          {:error, :deployment_cannot_be_cancelled}
        end
    end
  end
end
