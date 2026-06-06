defmodule GroceryAidWeb.IngredientLive.Show do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog
  alias GroceryAid.Catalog.StoreItem

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@ingredient.name}
        <:subtitle>{@ingredient.category}</:subtitle>
        <:actions>
          <.button navigate={~p"/ingredients"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button phx-click="lookup_nutrition" phx-disable-with="Looking up...">
            <.icon name="hero-magnifying-glass" class="size-4" />
            {if @ingredient.calories_per_100g, do: "Refresh calories", else: "Look up calories"}
          </.button>
          <.button variant="primary" navigate={~p"/ingredients/#{@ingredient}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item :if={@ingredient.default_unit} title="Default unit">
          {@ingredient.default_unit}
        </:item>
        <:item :if={@ingredient.calories_per_100g} title="Calories">
          {round(@ingredient.calories_per_100g)} kcal / 100g
          <span :if={@ingredient.fdc_description} class="text-xs opacity-60">
            · USDA: {@ingredient.fdc_description}
          </span>
        </:item>
        <:item :if={@ingredient.notes} title="Notes">{@ingredient.notes}</:item>
      </.list>

      <div class="card bg-base-200 mt-6">
        <div class="card-body">
          <h2 class="card-title">Where to buy</h2>

          <ul :if={@ingredient.store_items != []} class="divide-y divide-base-300">
            <li
              :for={si <- @ingredient.store_items}
              class="py-2 flex items-center justify-between gap-2"
            >
              <span class="flex-1">
                <.link navigate={~p"/stores/#{si.store}"} class="font-medium link link-hover">
                  {si.store.name}
                </.link>
                <span :if={si.aisle} class="text-xs opacity-60">· aisle {si.aisle}</span>
                <a
                  :if={si.product_url}
                  href={si.product_url}
                  target="_blank"
                  rel="noopener"
                  class="link link-primary text-xs ml-1"
                >
                  product
                </a>
              </span>
              <span :if={si.price} class="text-sm opacity-70">${si.price}</span>
              <.link
                phx-click="remove_store"
                phx-value-id={si.id}
                data-confirm="Remove?"
                class="text-error text-sm"
              >
                Remove
              </.link>
            </li>
          </ul>
          <p :if={@ingredient.store_items == []} class="opacity-70">
            Not linked to any store yet.
          </p>

          <.form
            :if={@store_options != []}
            for={@item_form}
            id="add-store-form"
            phx-submit="add_store"
            class="grid grid-cols-1 sm:grid-cols-5 gap-2 items-end mt-2"
          >
            <.input
              field={@item_form[:store_id]}
              type="select"
              label="Store"
              prompt="Pick one"
              options={@store_options}
            />
            <.input field={@item_form[:price]} type="number" step="any" label="Price" />
            <.input field={@item_form[:aisle]} type="text" label="Aisle" />
            <.input field={@item_form[:product_url]} type="text" label="Product URL" />
            <.button variant="primary">
              <.icon name="hero-plus" class="size-4" /> Add
            </.button>
          </.form>

          <p :if={@store_options == []} class="text-sm opacity-70">
            No stores yet. <.link navigate={~p"/stores/new"} class="link">Add one</.link>.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, socket |> assign(:ingredient_id, id) |> load()}
  end

  @impl true
  def handle_event("add_store", %{"store_item" => params}, socket) do
    params = Map.put(params, "ingredient_id", socket.assigns.ingredient_id)

    case Catalog.create_store_item(params) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Store added") |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, :item_form, to_form(changeset))}
    end
  end

  def handle_event("remove_store", %{"id" => id}, socket) do
    id |> Catalog.get_store_item!() |> Catalog.delete_store_item()
    {:noreply, socket |> put_flash(:info, "Removed") |> load()}
  end

  def handle_event("lookup_nutrition", _params, socket) do
    case Catalog.fetch_nutrition(socket.assigns.ingredient) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Calories updated from USDA") |> load()}

      {:error, :no_match} ->
        {:noreply, put_flash(socket, :error, "No USDA match found for that name.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Couldn't reach USDA — try again.")}
    end
  end

  defp load(socket) do
    ingredient = Catalog.get_ingredient_with_stores!(socket.assigns.ingredient_id)
    options = Catalog.list_stores() |> Enum.map(&{&1.name, &1.id})

    socket
    |> assign(:page_title, ingredient.name)
    |> assign(:ingredient, ingredient)
    |> assign(:store_options, options)
    |> assign(:item_form, to_form(Catalog.change_store_item(%StoreItem{})))
  end
end
