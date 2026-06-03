defmodule GroceryAidWeb.MealLive.Index do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Meals

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Meals
        <:subtitle>The dishes you like — your rotation.</:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/meals/new"}>
            <.icon name="hero-plus" /> New Meal
          </.button>
        </:actions>
      </.header>

      <.table
        id="meals"
        rows={@streams.meals}
        row_click={fn {_id, meal} -> JS.navigate(~p"/meals/#{meal}") end}
      >
        <:col :let={{_id, meal}} label="Name">{meal.name}</:col>
        <:col :let={{_id, meal}} label="Cuisine">{meal.cuisine}</:col>
        <:col :let={{_id, meal}} label="Rating">
          <span :if={meal.rating}>{String.duplicate("★", meal.rating)}</span>
        </:col>
        <:col :let={{_id, meal}} label="Tags">
          <span :for={tag <- meal.tags} class="badge badge-sm badge-outline mr-1">{tag.name}</span>
        </:col>
        <:action :let={{_id, meal}}>
          <div class="sr-only">
            <.link navigate={~p"/meals/#{meal}"}>Show</.link>
          </div>
          <.link navigate={~p"/meals/#{meal}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, meal}}>
          <.link
            phx-click={JS.push("delete", value: %{id: meal.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Meals")
     |> stream(:meals, list_meals())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    meal = Meals.get_meal!(id)
    {:ok, _} = Meals.delete_meal(meal)

    {:noreply, stream_delete(socket, :meals, meal)}
  end

  defp list_meals() do
    Meals.list_meals()
  end
end
