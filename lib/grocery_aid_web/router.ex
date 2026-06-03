defmodule GroceryAidWeb.Router do
  use GroceryAidWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GroceryAidWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GroceryAidWeb do
    pipe_through :browser

    live "/", DashboardLive, :index

    live "/ingredients", IngredientLive.Index, :index
    live "/ingredients/new", IngredientLive.Form, :new
    live "/ingredients/:id", IngredientLive.Show, :show
    live "/ingredients/:id/edit", IngredientLive.Form, :edit

    live "/stores", StoreLive.Index, :index
    live "/stores/new", StoreLive.Form, :new
    live "/stores/:id", StoreLive.Show, :show
    live "/stores/:id/edit", StoreLive.Form, :edit

    live "/meals", MealLive.Index, :index
    live "/meals/new", MealLive.Form, :new
    live "/meals/:id", MealLive.Show, :show
    live "/meals/:id/edit", MealLive.Form, :edit

    live "/shopping-list", ShoppingListLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", GroceryAidWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:grocery_aid, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GroceryAidWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
