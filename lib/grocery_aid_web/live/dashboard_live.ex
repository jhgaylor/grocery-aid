defmodule GroceryAidWeb.DashboardLive do
  use GroceryAidWeb, :live_view

  alias GroceryAid.{Catalog, Meals}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_dashboard(socket)}
  end

  @impl true
  def handle_event("reshuffle", _params, socket) do
    {:noreply, assign(socket, :suggestions, Meals.suggest_meals(3))}
  end

  defp assign_dashboard(socket) do
    socket
    |> assign(:page_title, "Grocery Aid")
    |> assign(:meal_count, Meals.count_meals())
    |> assign(:ingredient_count, Catalog.count_ingredients())
    |> assign(:store_count, Catalog.count_stores())
    |> assign(:suggestions, Meals.suggest_meals(3))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        What should I eat this week?
        <:subtitle>
          Keep a running catalog of the meals you like and where to buy what they need —
          then turn a few picks into a grocery list.
        </:subtitle>
      </.header>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.stat_card label="Meals" count={@meal_count} href={~p"/meals"} icon="hero-cake" />
        <.stat_card
          label="Ingredients"
          count={@ingredient_count}
          href={~p"/ingredients"}
          icon="hero-beaker"
        />
        <.stat_card
          label="Stores"
          count={@store_count}
          href={~p"/stores"}
          icon="hero-building-storefront"
        />
      </div>

      <div class="card bg-base-200 mt-4">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Tonight's suggestions</h2>
            <button class="btn btn-sm btn-ghost" phx-click="reshuffle">
              <.icon name="hero-arrow-path" class="size-4" /> Reshuffle
            </button>
          </div>

          <ul :if={@suggestions != []} class="divide-y divide-base-300">
            <li :for={meal <- @suggestions} class="py-2 flex items-center justify-between">
              <div>
                <.link navigate={~p"/meals/#{meal}"} class="font-medium link link-hover">
                  {meal.name}
                </.link>
                <div class="flex gap-1 mt-1">
                  <span :for={tag <- meal.tags} class="badge badge-sm badge-outline">
                    {tag.name}
                  </span>
                </div>
              </div>
              <span :if={meal.rating} class="text-sm opacity-70">
                {String.duplicate("★", meal.rating)}
              </span>
            </li>
          </ul>

          <p :if={@suggestions == []} class="opacity-70">
            No meals yet. <.link navigate={~p"/meals/new"} class="link">Add your first meal</.link>
            to get suggestions.
          </p>
        </div>
      </div>

      <div class="flex flex-wrap gap-2 mt-4">
        <.link navigate={~p"/meals/new"} class="btn btn-outline btn-sm">
          <.icon name="hero-plus" class="size-4" /> New meal
        </.link>
        <.link navigate={~p"/ingredients/new"} class="btn btn-outline btn-sm">
          <.icon name="hero-plus" class="size-4" /> New ingredient
        </.link>
        <.link navigate={~p"/stores/new"} class="btn btn-outline btn-sm">
          <.icon name="hero-plus" class="size-4" /> New store
        </.link>
        <.link navigate={~p"/shopping-list"} class="btn btn-primary btn-sm">
          <.icon name="hero-list-bullet" class="size-4" /> Build a shopping list
        </.link>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <.link navigate={@href} class="card bg-base-200 hover:bg-base-300 transition-colors">
      <div class="card-body flex-row items-center gap-4">
        <.icon name={@icon} class="size-8 text-primary" />
        <div>
          <div class="text-3xl font-bold">{@count}</div>
          <div class="text-sm opacity-70">{@label}</div>
        </div>
      </div>
    </.link>
    """
  end
end
