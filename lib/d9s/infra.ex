defmodule D9s.Infra do
  @moduledoc """
  The Infra context.
  """

  alias D9s.Infra.{Destination, Server}

  ## Destinations

  @doc """
  Returns the list of destinations.
  """
  @spec list_destinations() :: [Destination.t()]
  def list_destinations do
    raise "Not implemented"
  end

  @doc """
  Returns the list of destinations for an app.
  """
  @spec list_destinations_for_app(integer()) :: [Destination.t()]
  def list_destinations_for_app(_app_id) do
    raise "Not implemented"
  end

  @doc """
  Gets a single destination.

  Raises `Ecto.NoResultsError` if the Destination does not exist.
  """
  @spec get_destination!(integer()) :: Destination.t()
  def get_destination!(_id), do: raise("Not implemented")

  @doc """
  Gets a single destination.

  Returns `nil` if the Destination does not exist.
  """
  @spec get_destination(integer()) :: Destination.t() | nil
  def get_destination(_id), do: raise("Not implemented")

  @doc """
  Gets a single destination by app_id and name.

  Raises `Ecto.NoResultsError` if the Destination does not exist.
  """
  @spec get_destination_by_name!(integer(), String.t()) :: Destination.t()
  def get_destination_by_name!(_app_id, _name) do
    raise "Not implemented"
  end

  @doc """
  Gets a single destination by app_id and name.

  Returns `nil` if the Destination does not exist.
  """
  @spec get_destination_by_name(integer(), String.t()) :: Destination.t() | nil
  def get_destination_by_name(_app_id, _name) do
    raise "Not implemented"
  end

  @doc """
  Creates a destination.
  """
  @spec create_destination(map()) :: {:ok, Destination.t()} | {:error, Ecto.Changeset.t()}
  def create_destination(_attrs \\ %{}) do
    raise "Not implemented"
  end

  @doc """
  Updates a destination.
  """
  @spec update_destination(Destination.t(), map()) ::
          {:ok, Destination.t()} | {:error, Ecto.Changeset.t()}
  def update_destination(_destination, _attrs) do
    raise "Not implemented"
  end

  @doc """
  Deletes a destination.
  """
  @spec delete_destination(Destination.t()) ::
          {:ok, Destination.t()} | {:error, Ecto.Changeset.t()}
  def delete_destination(_destination) do
    raise "Not implemented"
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking destination changes.
  """
  @spec change_destination(Destination.t(), map()) :: Ecto.Changeset.t()
  def change_destination(_destination, _attrs \\ %{}) do
    raise "Not implemented"
  end

  ## Servers

  @doc """
  Returns the list of servers for a destination.
  """
  @spec list_servers_for_destination(integer()) :: [Server.t()]
  def list_servers_for_destination(_destination_id) do
    raise "Not implemented"
  end

  @doc """
  Gets a single server.

  Raises `Ecto.NoResultsError` if the Server does not exist.
  """
  @spec get_server!(integer()) :: Server.t()
  def get_server!(_id), do: raise("Not implemented")

  @doc """
  Gets a single server.

  Returns `nil` if the Server does not exist.
  """
  @spec get_server(integer()) :: Server.t() | nil
  def get_server(_id), do: raise("Not implemented")

  @doc """
  Creates a server.
  """
  @spec create_server(map()) :: {:ok, Server.t()} | {:error, Ecto.Changeset.t()}
  def create_server(_attrs \\ %{}) do
    raise "Not implemented"
  end

  @doc """
  Updates a server.
  """
  @spec update_server(Server.t(), map()) :: {:ok, Server.t()} | {:error, Ecto.Changeset.t()}
  def update_server(_server, _attrs) do
    raise "Not implemented"
  end

  @doc """
  Deletes a server.
  """
  @spec delete_server(Server.t()) :: {:ok, Server.t()} | {:error, Ecto.Changeset.t()}
  def delete_server(_server) do
    raise "Not implemented"
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking server changes.
  """
  @spec change_server(Server.t(), map()) :: Ecto.Changeset.t()
  def change_server(_server, _attrs \\ %{}) do
    raise "Not implemented"
  end

  @doc """
  Syncs servers for a destination.
  """
  @spec sync_servers_for_destination(integer()) :: {:ok, [Server.t()]} | {:error, term()}
  def sync_servers_for_destination(_destination_id) do
    raise "Not implemented"
  end
end
