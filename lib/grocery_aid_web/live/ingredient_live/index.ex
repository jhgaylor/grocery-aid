defmodule GroceryAidWeb.IngredientLive.Index do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Ingredients
        <:actions>
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
        <:col :let={{_id, ingredient}} label="Default unit">{ingredient.default_unit}</:col>
        <:col :let={{_id, ingredient}} label="Notes">{ingredient.notes}</:col>
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
     |> assign(:page_title, "Listing Ingredients")
     |> stream(:ingredients, list_ingredients())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ingredient = Catalog.get_ingredient!(id)
    {:ok, _} = Catalog.delete_ingredient(ingredient)

    {:noreply, stream_delete(socket, :ingredients, ingredient)}
  end

  defp list_ingredients() do
    Catalog.list_ingredients()
  end
end
