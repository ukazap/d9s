defmodule D9s.Apps do
  @moduledoc """
  The Apps context.
  """

  import Ecto.Query, warn: false
  alias D9s.Repo

  alias D9s.Apps.App
  alias D9s.Apps.Release

  ## Apps

  @doc """
  Returns the list of apps.

  ## Examples

      iex> list_apps()
      [%App{}, ...]

  """
  @spec list_apps() :: [App.t()]
  def list_apps do
    Repo.all(App)
  end

  @doc """
  Gets a single app.

  Raises `Ecto.NoResultsError` if the App does not exist.

  ## Examples

      iex> get_app!(123)
      %App{}

      iex> get_app!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_app!(integer()) :: App.t()
  def get_app!(id), do: Repo.get!(App, id)

  @doc """
  Gets a single app.

  Returns `nil` if the App does not exist.

  ## Examples

      iex> get_app(123)
      %App{}

      iex> get_app(456)
      nil

  """
  @spec get_app(integer()) :: App.t() | nil
  def get_app(id), do: Repo.get(App, id)

  @doc """
  Gets a single app by name.

  Raises `Ecto.NoResultsError` if the App does not exist.

  ## Examples

      iex> get_app_by_name!("my-app")
      %App{}

      iex> get_app_by_name!("nonexistent")
      ** (Ecto.NoResultsError)

  """
  @spec get_app_by_name!(String.t()) :: App.t()
  def get_app_by_name!(name), do: Repo.get_by!(App, name: name)

  @doc """
  Gets a single app by name.

  Returns `nil` if the App does not exist.

  ## Examples

      iex> get_app_by_name("my-app")
      %App{}

      iex> get_app_by_name("nonexistent")
      nil

  """
  @spec get_app_by_name(String.t()) :: App.t() | nil
  def get_app_by_name(name), do: Repo.get_by(App, name: name)

  @doc """
  Creates a app.

  ## Examples

      iex> create_app(%{field: value})
      {:ok, %App{}}

      iex> create_app(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_app(map()) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def create_app(attrs \\ %{}) do
    %App{}
    |> App.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a app.

  ## Examples

      iex> update_app(app, %{field: new_value})
      {:ok, %App{}}

      iex> update_app(app, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_app(App.t(), map()) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def update_app(%App{} = app, attrs) do
    app
    |> App.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a app.

  ## Examples

      iex> delete_app(app)
      {:ok, %App{}}

      iex> delete_app(app)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_app(App.t()) :: {:ok, App.t()} | {:error, Ecto.Changeset.t()}
  def delete_app(%App{} = app) do
    Repo.delete(app)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking app changes.

  ## Examples

      iex> change_app(app)
      %Ecto.Changeset{data: %App{}}

  """
  @spec change_app(App.t(), map()) :: Ecto.Changeset.t()
  def change_app(%App{} = app, attrs \\ %{}) do
    App.changeset(app, attrs)
  end

  ## Releases

  @doc """
  Returns the list of releases for an app.

  ## Examples

      iex> list_releases_for_app(123)
      [%Release{}, ...]

  """
  @spec list_releases_for_app(integer()) :: [Release.t()]
  def list_releases_for_app(app_id) do
    from(r in Release, where: r.app_id == ^app_id, order_by: [desc: r.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets the latest release for an app.

  Returns `nil` if no releases exist.

  ## Examples

      iex> get_latest_release_for_app(123)
      %Release{}

      iex> get_latest_release_for_app(456)
      nil

  """
  @spec get_latest_release_for_app(integer()) :: Release.t() | nil
  def get_latest_release_for_app(app_id) do
    from(r in Release,
      where: r.app_id == ^app_id,
      order_by: [desc: r.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Gets a single release.

  Raises `Ecto.NoResultsError` if the Release does not exist.

  ## Examples

      iex> get_release!(123)
      %Release{}

      iex> get_release!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_release!(integer()) :: Release.t()
  def get_release!(id), do: Repo.get!(Release, id)

  @doc """
  Gets a single release.

  Returns `nil` if the Release does not exist.

  ## Examples

      iex> get_release(123)
      %Release{}

      iex> get_release(456)
      nil

  """
  def get_release(id), do: Repo.get(Release, id)

  @doc """
  Gets a single release by app_id and version.

  Raises `Ecto.NoResultsError` if the Release does not exist.

  ## Examples

      iex> get_release_by_version!(123, "v1.0.0")
      %Release{}

      iex> get_release_by_version!(123, "nonexistent")
      ** (Ecto.NoResultsError)

  """
  @spec get_release_by_version!(integer(), String.t()) :: Release.t()
  def get_release_by_version!(app_id, version) do
    Repo.get_by!(Release, app_id: app_id, version: version)
  end

  @doc """
  Gets a single release by app_id and version.

  Returns `nil` if the Release does not exist.

  ## Examples

      iex> get_release_by_version(123, "v1.0.0")
      %Release{}

      iex> get_release_by_version(123, "nonexistent")
      nil

  """
  @spec get_release_by_version(integer(), String.t()) :: Release.t() | nil
  def get_release_by_version(app_id, version) do
    Repo.get_by(Release, app_id: app_id, version: version)
  end

  @doc """
  Creates a release.

  ## Examples

      iex> create_release(%{field: value})
      {:ok, %Release{}}

      iex> create_release(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_release(map()) :: {:ok, Release.t()} | {:error, Ecto.Changeset.t()}
  def create_release(attrs \\ %{}) do
    %Release{}
    |> Release.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a release.

  ## Examples

      iex> update_release(release, %{field: new_value})
      {:ok, %Release{}}

      iex> update_release(release, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_release(Release.t(), map()) :: {:ok, Release.t()} | {:error, Ecto.Changeset.t()}
  def update_release(%Release{} = release, attrs) do
    release
    |> Release.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a release.

  ## Examples

      iex> delete_release(release)
      {:ok, %Release{}}

      iex> delete_release(release)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_release(Release.t()) :: {:ok, Release.t()} | {:error, Ecto.Changeset.t()}
  def delete_release(%Release{} = release) do
    Repo.delete(release)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking release changes.

  ## Examples

      iex> change_release(release)
      %Ecto.Changeset{data: %Release{}}

  """
  @spec change_release(Release.t(), map()) :: Ecto.Changeset.t()
  def change_release(%Release{} = release, attrs \\ %{}) do
    Release.changeset(release, attrs)
  end
end
