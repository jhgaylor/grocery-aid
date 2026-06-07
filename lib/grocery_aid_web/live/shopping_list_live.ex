defmodule GroceryAidWeb.ShoppingListLive do
  use GroceryAidWeb, :live_view

  alias GroceryAid.{Catalog, Meals}

  @impl true
  def mount(_params, _session, socket) do
    meals = Meals.list_meals()

    {:ok,
     socket
     |> assign(:page_title, "Shopping List")
     |> assign(:meals, meals)
     |> assign(:meals_by_id, Map.new(meals, &{&1.id, &1}))
     |> assign(:base_servings, Map.new(meals, &{&1.id, &1.servings}))
     |> assign(:grocery_items, Catalog.list_grocery_items())
     |> assign(:selected, MapSet.new())
     |> assign(:targets, %{})
     |> assign(:selected_items, MapSet.new())
     |> assign(:groups, [])
     |> assign(:visible_groups, [])
     |> assign(:store_filter, "")
     |> assign(:list_text, "")
     |> assign(:calories, %{total: 0.0, with_data: 0, selected: 0})}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    id = String.to_integer(id)

    {selected, targets} =
      if MapSet.member?(socket.assigns.selected, id) do
        {MapSet.delete(socket.assigns.selected, id), Map.delete(socket.assigns.targets, id)}
      else
        # default a selected meal's target to its base yield (factor 1).
        {MapSet.put(socket.assigns.selected, id),
         Map.put(socket.assigns.targets, id, socket.assigns.base_servings[id])}
      end

    {:noreply, socket |> assign(selected: selected, targets: targets) |> recompute()}
  end

  def handle_event("set_servings", %{"id" => id, "value" => value}, socket) do
    id = String.to_integer(id)

    target =
      case Integer.parse(String.trim(value)) do
        {n, _} when n > 0 -> n
        _ -> nil
      end

    {:noreply,
     socket |> assign(:targets, Map.put(socket.assigns.targets, id, target)) |> recompute()}
  end

  def handle_event("toggle_item", %{"id" => id}, socket) do
    id = String.to_integer(id)
    sel = socket.assigns.selected_items

    sel = if MapSet.member?(sel, id), do: MapSet.delete(sel, id), else: MapSet.put(sel, id)
    {:noreply, socket |> assign(:selected_items, sel) |> recompute()}
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(selected: MapSet.new(), targets: %{}, selected_items: MapSet.new())
     |> recompute()}
  end

  def handle_event("shop_at", %{"store" => store}, socket) do
    {:noreply, socket |> assign(:store_filter, store) |> apply_view()}
  end

  defp recompute(socket) do
    socket
    |> assign(:groups, build_groups(socket.assigns))
    |> assign(:calories, calorie_total(socket.assigns))
    |> apply_view()
  end

  # Merge meal-ingredient groups and selected grocery items into one set of
  # per-store groups, each with `items` (ingredients) and `extras` (grocery
  # items). nil store → the "No store assigned" bucket.
  defp build_groups(a) do
    ing_groups = Meals.shopping_list(MapSet.to_list(a.selected), a.targets)
    items = Enum.filter(a.grocery_items, &MapSet.member?(a.selected_items, &1.id))
    extras_by_key = Enum.group_by(items, &store_key(&1.preferred_store))

    base =
      Map.new(ing_groups, &{store_key(&1.store), %{store: &1.store, items: &1.items, extras: []}})

    extras_by_key
    |> Enum.reduce(base, fn {key, exs}, acc ->
      existing = Map.get(acc, key, %{store: hd(exs).preferred_store, items: [], extras: []})
      Map.put(acc, key, %{existing | extras: exs})
    end)
    |> Map.values()
    |> Enum.sort_by(fn %{store: s} -> (s && s.name) || "~" end)
  end

  defp store_key(nil), do: :none
  defp store_key(%{id: id}), do: id

  # Narrow the displayed groups to the chosen store ("" = all, "none" =
  # unassigned, "<id>" = that store) and rebuild the copy-text from what's shown.
  defp apply_view(socket) do
    filter = socket.assigns.store_filter

    visible =
      Enum.filter(socket.assigns.groups, fn %{store: store} ->
        case filter do
          "" -> true
          "none" -> is_nil(store)
          id -> store && to_string(store.id) == id
        end
      end)

    socket
    |> assign(:visible_groups, visible)
    |> assign(:list_text, list_text(visible))
  end

  # Plaintext list (ingredients + grocery items) grouped by store, for Copy.
  defp list_text(groups) do
    groups
    |> Enum.map(fn g ->
      header = (g.store && g.store.name) || "No store assigned"

      rows =
        Enum.map(g.items, fn it ->
          q = Meals.format_quantities(it.quantities)
          "- " <> if(q == "", do: "", else: q <> " ") <> it.ingredient.name
        end) ++ Enum.map(g.extras, &"- #{&1.name}")

      Enum.join([header | rows], "\n")
    end)
    |> Enum.join("\n\n")
  end

  # Rough kcal across selected meals, each scaled by its target/base servings.
  defp calorie_total(a) do
    {total, with_data} =
      Enum.reduce(a.selected, {0.0, 0}, fn id, {sum, n} ->
        meal = a.meals_by_id[id]
        factor = scale_factor(a.base_servings[id], a.targets[id])
        nut = Meals.meal_nutrition(meal, factor)
        if nut.counted > 0, do: {sum + nut.total, n + 1}, else: {sum, n}
      end)

    %{total: total, with_data: with_data, selected: MapSet.size(a.selected)}
  end

  defp scale_factor(base, target) do
    if is_integer(base) and base > 0 and is_integer(target) and target > 0,
      do: Decimal.div(Decimal.new(target), Decimal.new(base)),
      else: Decimal.new(1)
  end

  defp store_options(groups), do: groups |> Enum.map(& &1.store) |> Enum.reject(&is_nil/1)
  defp has_unassigned?(groups), do: Enum.any?(groups, &is_nil(&1.store))

  defp fmt(quantities), do: Meals.format_quantities(quantities)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Shopping List
        <:subtitle>Pick meals and grocery items; we'll roll them up by store.</:subtitle>
        <:actions>
          <button
            :if={MapSet.size(@selected) + MapSet.size(@selected_items) > 0}
            class="btn btn-ghost btn-sm"
            phx-click="clear"
          >
            Clear
          </button>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="space-y-4">
          <div>
            <h2 class="font-semibold mb-2">Meals</h2>
            <p :if={@meals == []} class="opacity-70 text-sm">
              No meals yet. <.link navigate={~p"/meals/new"} class="link">Add one</.link>.
            </p>
            <ul :if={@meals != []} class="bg-base-200 rounded-box divide-y divide-base-300">
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
            <h2 class="font-semibold mb-2">Grocery items</h2>
            <p :if={@grocery_items == []} class="opacity-70 text-sm">
              No grocery items yet.
              <.link navigate={~p"/grocery-items"} class="link">Add cookies, cereal, …</.link>
            </p>
            <ul :if={@grocery_items != []} class="bg-base-200 rounded-box divide-y divide-base-300">
              <li :for={gi <- @grocery_items} class="flex items-center gap-3 px-3 py-2">
                <label class="flex items-center gap-3 flex-1 cursor-pointer min-w-0">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    checked={MapSet.member?(@selected_items, gi.id)}
                    phx-click="toggle_item"
                    phx-value-id={gi.id}
                  />
                  <span class="truncate">{gi.name}</span>
                </label>
                <span :if={gi.preferred_store} class="badge badge-xs badge-ghost shrink-0">
                  {gi.preferred_store.name}
                </span>
              </li>
            </ul>
          </div>
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
          <p :if={@groups == []} class="opacity-70">
            Select meals or grocery items to build your list.
          </p>

          <form :if={@groups != []} phx-change="shop_at" class="mb-3">
            <label class="form-control">
              <span class="label-text text-xs">Shopping at</span>
              <select name="store" class="select select-sm select-bordered">
                <option value="" selected={@store_filter == ""}>All stores</option>
                <option
                  :for={store <- store_options(@groups)}
                  value={store.id}
                  selected={@store_filter == to_string(store.id)}
                >
                  {store.name}
                </option>
                <option
                  :if={has_unassigned?(@groups)}
                  value="none"
                  selected={@store_filter == "none"}
                >
                  No store assigned
                </option>
              </select>
            </label>
          </form>

          <div :if={@calories.with_data > 0} class="text-sm opacity-80 mb-2">
            ≈ <span class="font-semibold">{round(@calories.total)} kcal</span>
            total
            <span :if={@calories.with_data < @calories.selected} class="opacity-60">
              (from {@calories.with_data} of {@calories.selected} meals with calorie data)
            </span>
          </div>

          <p :if={@groups != [] and @visible_groups == []} class="opacity-70">
            Nothing on your list for that store.
          </p>

          <div :for={group <- @visible_groups} class="card bg-base-200 mb-3">
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
                <li
                  :for={x <- group.extras}
                  class="py-1.5 flex items-center justify-between text-base-content/90"
                >
                  <span>
                    {x.name}
                    <span :if={x.notes} class="text-xs opacity-60">— {x.notes}</span>
                  </span>
                  <span class="badge badge-xs badge-ghost">item</span>
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
end
