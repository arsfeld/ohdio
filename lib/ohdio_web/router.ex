defmodule OhdioWeb.Router do
  use OhdioWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OhdioWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OhdioWeb do
    pipe_through :browser

    live "/", QueueLive
    live "/library", LibraryLive

    get "/files/audio/:id", FileController, :audio
    get "/files/cover/:id", FileController, :cover
  end

  # Other scopes may use custom stacks.
  # scope "/api", OhdioWeb do
  #   pipe_through :api
  # end
end
