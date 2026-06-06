defmodule GroceryAidWeb.MealLive.Index do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Meals

  @sorts [{"Name", "name"}, {"Rating", "rating"}, {"Recently made", "recent"}]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Meals
        <:subtitle>The dishes you like — your rotation.</:subtitle>
        <:actions>
          <.button navigate={~p"/meals/generate"}>
            <.icon name="hero-sparkles" /> Describe a meal
          </.button>
          <.button navigate={~p"/meals/import"}>
            <.icon name="hero-arrow-down-tray" /> Import from URL
          </.button>
          <.button variant="primary" navigate={~p"/meals/new"}>
            <.icon name="hero-plus" /> New Meal
          </.button>
        </:actions>
      </.header>

      <form phx-change="filter" class="flex flex-wrap items-end gap-3 mb-2">
        <label class="form-control">
          <span class="label-text text-xs">Tag</span>
          <select name="tag" class="select select-sm select-bordered">
            <option value="" selected={@tag == ""}>All tags</option>
            <option :for={t <- @all_tags} value={t} selected={@tag == t}>{t}</option>
          </select>
        </label>
        <label class="form-control">
          <span class="label-text text-xs">Sort by</span>
          <select name="sort" class="select select-sm select-bordered">
            <option :for={{label, val} <- sorts()} value={val} selected={@sort == val}>
              {label}
            </option>
          </select>
        </label>
        <span class="text-sm opacity-60">{@count} meal{if @count == 1, do: "", else: "s"}</span>
      </form>

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
        <:col :let={{_id, meal}} label="Last made">{meal.last_made_on}</:col>
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
     |> assign(:page_title, "Meals")
     |> assign(:all_tags, Enum.map(Meals.list_tags(), & &1.name))
     |> assign(:tag, "")
     |> assign(:sort, "name")
     |> load_meals()}
  end

  @impl true
  def handle_event("filter", %{"tag" => tag, "sort" => sort}, socket) do
    {:noreply, socket |> assign(tag: tag, sort: sort) |> load_meals()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    meal = Meals.get_meal!(id)
    {:ok, _} = Meals.delete_meal(meal)
    {:noreply, socket |> stream_delete(:meals, meal) |> assign(:count, socket.assigns.count - 1)}
  end

  defp load_meals(socket) do
    meals = Meals.list_meals(tag: socket.assigns.tag, sort: sort_atom(socket.assigns.sort))

    socket
    |> assign(:count, length(meals))
    |> stream(:meals, meals, reset: true)
  end

  defp sort_atom("rating"), do: :rating
  defp sort_atom("recent"), do: :recent
  defp sort_atom(_), do: :name

  defp sorts, do: @sorts
end
