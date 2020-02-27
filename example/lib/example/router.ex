defmodule Example.Router do
  use Example, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Example do
    pipe_through :browser

    live "/", PDFLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", Example do
  #   pipe_through :api
  # end
end
