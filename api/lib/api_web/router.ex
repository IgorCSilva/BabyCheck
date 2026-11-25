defmodule ApiWeb.Router do
  use ApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_cookies
  end

  pipeline :authenticated do
    plug ApiWeb.Auth.Pipeline
  end

  scope "/api", ApiWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    delete "/auth/logout", AuthController, :logout
    post "/auth/password_resets", AuthController, :request_password_reset
    put "/auth/password_resets/:token", AuthController, :reset_password

    scope "/" do
      pipe_through :authenticated

      get "/me", ProfileController, :show
    end
  end
end
