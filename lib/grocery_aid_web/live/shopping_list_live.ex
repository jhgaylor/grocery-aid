defmodule GroceryAidWeb.ShoppingListLive do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Meals

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Shopping List")
     |> assign(:meals, Meals.list_meals())
     |> assign(:selected, MapSet.new())
     |> assign(:groups, [])}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    id = String.to_integer(id)

    selected =
      if MapSet.member?(socket.assigns.selected, id) do
        MapSet.delete(socket.assigns.selected, id)
      else
        MapSet.put(socket.assigns.selected, id)
      end

    {:noreply, recompute(socket, selected)}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, recompute(socket, MapSet.new())}
  end

  defp recompute(socket, selected) do
    groups = selected |> MapSet.to_list() |> Meals.shopping_list()

    socket
    |> assign(:selected, selected)
    |> assign(:groups, groups)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Shopping List
        <:subtitle>
          Pick the meals you want to make. We'll roll up the ingredients by store.
        </:subtitle>
        <:actions>
          <button :if={MapSet.size(@selected) > 0} class="btn btn-ghost btn-sm" phx-click="clear">
            Clear ({MapSet.size(@selected)})
          </button>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <h2 class="font-semibold mb-2">Meals</h2>
          <p :if={@meals == []} class="opacity-70">
            No meals yet. <.link navigate={~p"/meals/new"} class="link">Add one</.link>.
          </p>
          <ul class="menu bg-base-200 rounded-box w-full">
            <li :for={meal <- @meals}>
              <label class="flex items-center gap-3 cursor-pointer">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm"
                  checked={MapSet.member?(@selected, meal.id)}
                  phx-click="toggle"
                  phx-value-id={meal.id}
                />
                <span class="flex-1">{meal.name}</span>
                <span class="flex gap-1">
                  <span :for={tag <- meal.tags} class="badge badge-xs badge-outline">{tag.name}</span>
                </span>
              </label>
            </li>
          </ul>
        </div>

        <div>
          <h2 class="font-semibold mb-2">Grocery list</h2>
          <p :if={@groups == []} class="opacity-70">Select meals to build your list.</p>

          <div :for={group <- @groups} class="card bg-base-200 mb-3">
            <div class="card-body p-4">
              <h3 class="font-semibold flex items-center gap-2">
                <.icon name="hero-building-storefront" class="size-4 text-primary" />
                {(group.store && group.store.name) || "No store assigned yet"}
              </h3>
              <ul class="divide-y divide-base-300">
                <li :for={item <- group.items} class="py-1.5 flex items-center justify-between">
                  <span>
                    {item.ingredient.name}
                    <span :if={item.store_item && item.store_item.aisle} class="text-xs opacity-60">
                      · aisle {item.store_item.aisle}
                    </span>
                  </span>
                  <span class="flex items-center gap-2">
                    <span :if={item.store_item && item.store_item.price} class="text-sm opacity-70">
                      ${item.store_item.price}
                    </span>
                    <a
                      :if={item.store_item && item.store_item.product_url}
                      href={item.store_item.product_url}
                      target="_blank"
                      rel="noopener"
                      class="link link-primary text-xs"
                    >
                      buy
                    </a>
                  </span>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
