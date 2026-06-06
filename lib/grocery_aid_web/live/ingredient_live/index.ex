defmodule GroceryAidWeb.IngredientLive.Index do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Ingredients
        <:subtitle>Your pantry of building blocks.</:subtitle>
        <:actions>
          <.button :if={@missing > 0} phx-click="fetch_missing" phx-disable-with="Fetching...">
            <.icon name="hero-bolt" class="size-4" /> Fetch calories ({@missing})
          </.button>
          <.button variant="primary" navigate={~p"/ingredients/new"}>
            <.icon name="hero-plus" /> New Ingredient
          </.button>
        </:actions>
      </.header>

      <.table
        id="ingredients"
        rows={@streams.ingredients}
        row_click={fn {_id, ingredient} -> JS.navigate(~p"/ingredients/#{ingredient}") end}
      >
        <:col :let={{_id, ingredient}} label="Name">{ingredient.name}</:col>
        <:col :let={{_id, ingredient}} label="Category">{ingredient.category}</:col>
        <:col :let={{_id, ingredient}} label="kcal/100g">
          <span :if={ingredient.calories_per_100g}>{round(ingredient.calories_per_100g)}</span>
        </:col>
        <:col :let={{_id, ingredient}} label="Default unit">{ingredient.default_unit}</:col>
        <:action :let={{_id, ingredient}}>
          <div class="sr-only">
            <.link navigate={~p"/ingredients/#{ingredient}"}>Show</.link>
          </div>
          <.link navigate={~p"/ingredients/#{ingredient}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, ingredient}}>
          <.link
            phx-click={JS.push("delete", value: %{id: ingredient.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "Ingredients")
     |> assign_missing()
     |> stream(:ingredients, Catalog.list_ingredients())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ingredient = Catalog.get_ingredient!(id)
    {:ok, _} = Catalog.delete_ingredient(ingredient)

    {:noreply, socket |> stream_delete(:ingredients, ingredient) |> assign_missing()}
  end

  def handle_event("fetch_missing", _params, socket) do
    %{ok: ok, failed: failed} = Catalog.fetch_missing_nutrition()

    msg =
      "Fetched calories for #{ok} ingredient(s)" <>
        if failed > 0, do: " (#{failed} had no USDA match)", else: ""

    {:noreply,
     socket
     |> put_flash(:info, msg)
     |> assign_missing()
     |> stream(:ingredients, Catalog.list_ingredients(), reset: true)}
  end

  defp assign_missing(socket) do
    assign(socket, :missing, length(Catalog.list_ingredients_without_nutrition()))
  end
end
