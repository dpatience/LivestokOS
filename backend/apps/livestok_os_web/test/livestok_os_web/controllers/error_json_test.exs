defmodule LivestokOsWeb.ErrorJSONTest do
  use LivestokOsWeb.ConnCase, async: true

  test "renders 404" do
    assert LivestokOsWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert LivestokOsWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
