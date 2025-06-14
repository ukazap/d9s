defmodule D9sWeb.ErrorJSONTest do
  use D9sWeb.ConnCase, async: true

  test "renders 404" do
    assert D9sWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert D9sWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
