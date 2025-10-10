defmodule OhdioWeb.ErrorJSONTest do
  use OhdioWeb.ConnCase, async: true

  test "renders 404" do
    assert OhdioWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert OhdioWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
