defmodule OhdioWeb.PageController do
  use OhdioWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
