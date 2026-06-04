defmodule GroceryAidWeb.ShoppingListLive do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Meals

  @impl true
  def mount(_params, _session, socket) do
    meals = Meals.list_meals()

    {:ok,
     socket
     |> assign(:page_title, "Shopping List")
     |> assign(:meals, meals)
     |> assign(:base_servings, Map.new(meals, &{&1.id, &1.servings}))
     |> assign(:selected, MapSet.new())
     |> assign(:targets, %{})
     |> assign(:groups, [])
     |> assign(:list_text, "")}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    id = String.to_integer(id)

    if MapSet.member?(socket.assigns.selected, id) do
      selected = MapSet.delete(socket.assigns.selected, id)
      {:noreply, recompute(socket, selected, Map.delete(socket.assigns.targets, id))}
    else
      selected = MapSet.put(socket.assigns.selected, id)
      # default a selected meal's target to its base yield (factor 1).
      targets = Map.put(socket.assigns.targets, id, socket.assigns.base_servings[id])
      {:noreply, recompute(socket, selected, targets)}
    end
  end

  def handle_event("set_servings", %{"id" => id, "value" => value}, socket) do
    id = String.to_integer(id)

    target =
      case Integer.parse(String.trim(value)) do
        {n, _} when n > 0 -> n
        _ -> nil
      end

    {:noreply,
     recompute(socket, socket.assigns.selected, Map.put(socket.assigns.targets, id, target))}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, recompute(socket, MapSet.new(), %{})}
  end

  defp recompute(socket, selected, targets) do
    groups = Meals.shopping_list(MapSet.to_list(selected), targets)

    socket
    |> assign(:selected, selected)
    |> assign(:targets, targets)
    |> assign(:groups, groups)
    |> assign(:list_text, Meals.shopping_list_text(groups))
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
          <ul class="bg-base-200 rounded-box divide-y divide-base-300">
            <li :for={meal <- @meals} class="flex items-center gap-3 px-3 py-2">
              <label class="flex items-center gap-3 flex-1 cursor-pointer min-w-0">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm"
                  checked={MapSet.member?(@selected, meal.id)}
                  phx-click="toggle"
                  phx-value-id={meal.id}
                />
                <span class="truncate">{meal.name}</span>
                <span class="flex gap-1 shrink-0">
                  <span :for={tag <- meal.tags} class="badge badge-xs badge-outline">{tag.name}</span>
                </span>
              </label>
              <form
                :if={MapSet.member?(@selected, meal.id) and meal.servings}
                phx-change="set_servings"
                phx-value-id={meal.id}
                class="flex items-center gap-1 shrink-0"
              >
                <input
                  type="number"
                  name="value"
                  value={Map.get(@targets, meal.id) || meal.servings}
                  min="1"
                  class="input input-xs input-bordered w-14"
                />
                <span class="text-xs opacity-50">/ {meal.servings}</span>
              </form>
            </li>
          </ul>
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <h2 class="font-semibold">Grocery list</h2>
            <button
              :if={@groups != []}
              type="button"
              class="btn btn-xs btn-ghost"
              onclick="navigator.clipboard.writeText(document.getElementById('list-text').value); this.querySelector('span').textContent='Copied!'"
            >
              <.icon name="hero-clipboard-document" class="size-3" /> <span>Copy</span>
            </button>
          </div>
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
                    <span :if={fmt(item.quantities) != ""} class="font-medium">
                      {fmt(item.quantities)}
                    </span>
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

          <%!-- Hidden source for the Copy button (also selectable as a fallback). --%>
          <textarea id="list-text" class="sr-only" readonly>{@list_text}</textarea>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp fmt(quantities), do: Meals.format_quantities(quantities)
end
