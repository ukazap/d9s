defmodule D9s.AppsTest do
  use D9s.DataCase

  alias D9s.Apps
  alias D9s.Apps.{App, Release}

  describe "apps" do
    @valid_attrs %{name: "test-app", description: "Test application"}
    @invalid_attrs %{name: nil, description: nil}

    def app_fixture(attrs \\ %{}) do
      {:ok, app} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Apps.create_app()

      app
    end

    test "list_apps/0 returns all apps" do
      app = app_fixture()
      assert Apps.list_apps() == [app]
    end

    test "get_app!/1 returns the app with given id" do
      app = app_fixture()
      assert Apps.get_app!(app.id) == app
    end

    test "get_app/1 returns the app with given id" do
      app = app_fixture()
      assert Apps.get_app(app.id) == app
    end

    test "get_app/1 returns nil for invalid id" do
      assert Apps.get_app(999) == nil
    end

    test "get_app_by_name!/1 returns the app with given name" do
      app = app_fixture()
      assert Apps.get_app_by_name!(app.name) == app
    end

    test "get_app_by_name/1 returns the app with given name" do
      app = app_fixture()
      assert Apps.get_app_by_name(app.name) == app
    end

    test "get_app_by_name/1 returns nil for invalid name" do
      assert Apps.get_app_by_name("nonexistent") == nil
    end

    test "create_app/1 with valid data creates a app" do
      valid_attrs = %{name: "my-app", description: "some description"}

      assert {:ok, %App{} = app} = Apps.create_app(valid_attrs)
      assert app.name == "my-app"
      assert app.description == "some description"
    end

    test "create_app/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Apps.create_app(@invalid_attrs)
    end

    test "create_app/1 with duplicate name returns error changeset" do
      app_fixture(%{name: "duplicate"})
      assert {:error, %Ecto.Changeset{}} = Apps.create_app(%{name: "duplicate"})
    end

    test "update_app/2 with valid data updates the app" do
      app = app_fixture()
      update_attrs = %{name: "updated-name", description: "updated description"}

      assert {:ok, %App{} = app} = Apps.update_app(app, update_attrs)
      assert app.name == "updated-name"
      assert app.description == "updated description"
    end

    test "update_app/2 with invalid data returns error changeset" do
      app = app_fixture()
      assert {:error, %Ecto.Changeset{}} = Apps.update_app(app, @invalid_attrs)
      assert app == Apps.get_app!(app.id)
    end

    test "delete_app/1 deletes the app" do
      app = app_fixture()
      assert {:ok, %App{}} = Apps.delete_app(app)
      assert_raise Ecto.NoResultsError, fn -> Apps.get_app!(app.id) end
    end

    test "change_app/1 returns a app changeset" do
      app = app_fixture()
      assert %Ecto.Changeset{} = Apps.change_app(app)
    end
  end

  describe "releases" do
    @valid_attrs %{version: "v1.0.0", metadata: %{"commit" => "abc123"}}
    @invalid_attrs %{version: nil, app_id: nil}

    def release_fixture(attrs \\ %{}) do
      app =
        if attrs[:app_id] do
          Apps.get_app!(attrs[:app_id])
        else
          app_fixture(%{name: "test-app-#{System.unique_integer([:positive])}"})
        end

      {:ok, release} =
        attrs
        |> Map.delete(:app_id)
        |> Enum.into(Map.put(@valid_attrs, :app_id, app.id))
        |> Apps.create_release()

      release
    end

    test "list_releases_for_app/1 returns all releases for an app" do
      app = app_fixture()
      release1 = release_fixture(%{app_id: app.id, version: "v1.0.0"})
      release2 = release_fixture(%{app_id: app.id, version: "v2.0.0"})

      releases = Apps.list_releases_for_app(app.id)
      assert length(releases) == 2

      # Verify both releases are returned (order may vary due to timestamp precision)
      release_ids = Enum.map(releases, & &1.id) |> Enum.sort()
      assert release_ids == [release1.id, release2.id]
    end

    test "get_latest_release_for_app/1 returns the latest release" do
      app = app_fixture()
      # Create releases with explicit timestamps
      {:ok, release1} =
        Apps.create_release(%{
          app_id: app.id,
          version: "v1.0.0",
          metadata: %{}
        })

      # Update the first release's timestamp to be older
      Repo.update_all(
        from(r in Release, where: r.id == ^release1.id),
        set: [inserted_at: ~U[2023-01-01 00:00:00Z]]
      )

      {:ok, release2} =
        Apps.create_release(%{
          app_id: app.id,
          version: "v2.0.0",
          metadata: %{}
        })

      latest = Apps.get_latest_release_for_app(app.id)
      assert latest.id == release2.id
      assert latest.version == "v2.0.0"
    end

    test "get_latest_release_for_app/1 returns nil when no releases exist" do
      app = app_fixture()
      assert Apps.get_latest_release_for_app(app.id) == nil
    end

    test "get_release!/1 returns the release with given id" do
      release = release_fixture()
      assert Apps.get_release!(release.id) == release
    end

    test "get_release/1 returns the release with given id" do
      release = release_fixture()
      assert Apps.get_release(release.id) == release
    end

    test "get_release/1 returns nil for invalid id" do
      assert Apps.get_release(999) == nil
    end

    test "get_release_by_version!/1 returns the release with given app_id and version" do
      release = release_fixture(%{version: "v1.2.3"})
      app = Apps.get_app!(release.app_id)

      found_release = Apps.get_release_by_version!(app.id, "v1.2.3")
      assert found_release.id == release.id
    end

    test "get_release_by_version/2 returns the release with given app_id and version" do
      release = release_fixture(%{version: "v1.2.3"})
      app = Apps.get_app!(release.app_id)

      found_release = Apps.get_release_by_version(app.id, "v1.2.3")
      assert found_release.id == release.id
    end

    test "get_release_by_version/2 returns nil for invalid version" do
      app = app_fixture()
      assert Apps.get_release_by_version(app.id, "nonexistent") == nil
    end

    test "create_release/1 with valid data creates a release" do
      app = app_fixture()
      valid_attrs = %{version: "v1.0.0", metadata: %{}, app_id: app.id}

      assert {:ok, %Release{} = release} = Apps.create_release(valid_attrs)
      assert release.version == "v1.0.0"
      assert release.metadata == %{}
      assert release.app_id == app.id
    end

    test "create_release/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Apps.create_release(@invalid_attrs)
    end

    test "create_release/1 with duplicate version for same app returns error changeset" do
      app = app_fixture()
      Apps.create_release(%{version: "v1.0.0", app_id: app.id})

      assert {:error, %Ecto.Changeset{}} =
               Apps.create_release(%{version: "v1.0.0", app_id: app.id})
    end

    test "create_release/1 allows same version for different apps" do
      app1 = app_fixture(%{name: "app1"})
      app2 = app_fixture(%{name: "app2"})

      assert {:ok, _} = Apps.create_release(%{version: "v1.0.0", app_id: app1.id})
      assert {:ok, _} = Apps.create_release(%{version: "v1.0.0", app_id: app2.id})
    end

    test "update_release/2 with valid data updates the release" do
      release = release_fixture()
      update_attrs = %{version: "v1.0.1", metadata: %{"commit" => "xyz789"}}

      assert {:ok, %Release{} = release} = Apps.update_release(release, update_attrs)
      assert release.version == "v1.0.1"
      assert release.metadata == %{"commit" => "xyz789"}
    end

    test "update_release/2 with invalid data returns error changeset" do
      release = release_fixture()
      assert {:error, %Ecto.Changeset{}} = Apps.update_release(release, @invalid_attrs)
      assert release == Apps.get_release!(release.id)
    end

    test "delete_release/1 deletes the release" do
      release = release_fixture()
      assert {:ok, %Release{}} = Apps.delete_release(release)
      assert_raise Ecto.NoResultsError, fn -> Apps.get_release!(release.id) end
    end

    test "change_release/1 returns a release changeset" do
      release = release_fixture()
      assert %Ecto.Changeset{} = Apps.change_release(release)
    end
  end
end
