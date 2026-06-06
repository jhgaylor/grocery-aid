defmodule GroceryAidWeb.MealLive.Show do
  use GroceryAidWeb, :live_view

  alias GroceryAid.{Catalog, Meals}
  alias GroceryAid.Meals.MealIngredient

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@meal.name}
        <:subtitle>{@meal.cuisine}</:subtitle>
        <:actions>
          <.button navigate={~p"/meals"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button phx-click="mark_made">
            <.icon name="hero-check-circle" class="size-4" /> Made it today
          </.button>
          <.button variant="primary" navigate={~p"/meals/#{@meal}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit meal
          </.button>
        </:actions>
      </.header>

      <div class="flex flex-wrap gap-1 mb-2">
        <span :for={tag <- @meal.tags} class="badge badge-outline">{tag.name}</span>
      </div>

      <.list>
        <:item :if={@meal.rating} title="Rating">{String.duplicate("★", @meal.rating)}</:item>
        <:item :if={@meal.prep_minutes} title="Prep time">{@meal.prep_minutes} min</:item>
        <:item :if={@meal.last_made_on} title="Last made">{@meal.last_made_on}</:item>
        <:item :if={@meal.source_url} title="Recipe">
          <a href={@meal.source_url} target="_blank" rel="noopener" class="link link-primary">
            {@meal.source_url}
          </a>
        </:item>
        <:item :if={@meal.description} title="Description">{@meal.description}</:item>
        <:item :if={@meal.notes} title="Notes">{@meal.notes}</:item>
      </.list>

      <div class="card bg-base-200 mt-6">
        <div class="card-body">
          <h2 class="card-title">Ingredients</h2>

          <div
            :if={@meal.meal_ingredients != []}
            class="flex flex-wrap items-center gap-x-3 gap-y-2 text-sm"
          >
            <span class="opacity-70">
              {if @meal.servings, do: "Makes #{@meal.servings} ·", else: "Scale:"}
            </span>
            <div class="join">
              <button
                :for={f <- ["0.5", "1", "2", "3"]}
                type="button"
                class={["btn btn-xs join-item", scale_is?(@scale, f) && "btn-primary"]}
                phx-click="scale_by"
                phx-value-factor={f}
              >
                {if f == "0.5", do: "½×", else: "#{f}×"}
              </button>
            </div>
            <form :if={@meal.servings} phx-change="scale_to" class="flex items-center gap-1">
              <span class="opacity-70">make</span>
              <input
                type="number"
                name="target"
                value={current_target(@meal.servings, @scale)}
                min="1"
                class="input input-xs input-bordered w-16"
              />
              <span class="opacity-70">servings</span>
            </form>
            <span :if={scaled?(@scale)} class="badge badge-sm badge-primary badge-outline">
              ×{format_qty(@scale)}
            </span>
          </div>

          <ul :if={@meal.meal_ingredients != []} class="divide-y divide-base-300">
            <li :for={mi <- @meal.meal_ingredients} class="py-2 flex items-center justify-between">
              <span>
                <span :if={mi.quantity} class="font-medium">
                  {format_qty(scale_qty(mi.quantity, @scale))} {mi.unit}
                </span>
                {mi.ingredient.name}
                <span :if={mi.notes} class="text-xs opacity-60">— {mi.notes}</span>
              </span>
              <.link
                phx-click="remove_ingredient"
                phx-value-id={mi.id}
                data-confirm="Remove this ingredient?"
                class="text-error text-sm"
              >
                Remove
              </.link>
            </li>
          </ul>
          <p :if={@meal.meal_ingredients == []} class="opacity-70">No ingredients yet.</p>

          <.form
            :if={@ingredient_options != []}
            for={@line_form}
            id="add-ingredient-form"
            phx-submit="add_ingredient"
            class="grid grid-cols-1 sm:grid-cols-4 gap-2 items-end mt-2"
          >
            <.input
              field={@line_form[:ingredient_id]}
              type="select"
              label="Ingredient"
              prompt="Pick one"
              options={@ingredient_options}
            />
            <.input field={@line_form[:quantity]} type="number" step="any" label="Qty" />
            <.input field={@line_form[:unit]} type="text" label="Unit" />
            <.button variant="primary">
              <.icon name="hero-plus" class="size-4" /> Add
            </.button>
          </.form>

          <p :if={@ingredient_options == []} class="text-sm opacity-70">
            No ingredients in your catalog yet. <.link navigate={~p"/ingredients/new"} class="link">Add one</.link>.
          </p>
        </div>
      </div>

      <div :if={@meal.meal_ingredients != []} class="card bg-base-200 mt-4">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Nutrition</h2>
            <button
              class="btn btn-xs btn-ghost"
              phx-click="calc_nutrition"
              phx-disable-with="Calculating..."
            >
              <.icon name="hero-calculator" class="size-4" />
              {if @nutrition_computed, do: "Recalculate", else: "Calculate calories"}
            </button>
          </div>

          <div :if={@nutrition_computed}>
            <div class="flex items-baseline gap-4 flex-wrap">
              <div :if={@nutrition.per_serving} class="text-2xl font-bold">
                {round(scaled(@nutrition.per_serving, @scale))}
                <span class="text-sm font-normal opacity-70">kcal / serving</span>
              </div>
              <div class="opacity-70 text-sm">
                {round(scaled(@nutrition.total, @scale))} kcal total{if @meal.servings,
                  do: " · #{current_target(@meal.servings, @scale)} servings"}
              </div>
            </div>
            <p
              :if={@nutrition.counted < @nutrition.total_lines}
              class="text-xs opacity-60 mt-1"
            >
              Based on {@nutrition.counted} of {@nutrition.total_lines} ingredients — others are
              missing USDA data.
            </p>
          </div>

          <p :if={not @nutrition_computed} class="opacity-70 text-sm">
            Estimate calories from USDA FoodData Central + your ingredient amounts.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, socket |> assign(:meal_id, id) |> assign(:scale, Decimal.new(1)) |> load_meal()}
  end

  @impl true
  def handle_event("add_ingredient", %{"meal_ingredient" => params}, socket) do
    case Meals.add_meal_ingredient(socket.assigns.meal, params) do
      {:ok, _mi} ->
        {:noreply, socket |> put_flash(:info, "Ingredient added") |> load_meal()}

      {:error, changeset} ->
        {:noreply, assign(socket, :line_form, to_form(changeset))}
    end
  end

  def handle_event("remove_ingredient", %{"id" => id}, socket) do
    id |> Meals.get_meal_ingredient!() |> Meals.delete_meal_ingredient()
    {:noreply, socket |> put_flash(:info, "Ingredient removed") |> load_meal()}
  end

  def handle_event("mark_made", _params, socket) do
    {:ok, _} = Meals.mark_made(socket.assigns.meal)
    {:noreply, socket |> put_flash(:info, "Marked as made today") |> load_meal()}
  end

  def handle_event("calc_nutrition", _params, socket) do
    {:ok, _} = Meals.calculate_nutrition(socket.assigns.meal)
    {:noreply, socket |> put_flash(:info, "Calculated calories") |> load_meal()}
  end

  def handle_event("scale_by", %{"factor" => f}, socket) do
    case Decimal.parse(f) do
      {scale, _} -> {:noreply, assign(socket, :scale, scale)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("scale_to", %{"target" => t}, socket) do
    servings = socket.assigns.meal.servings

    scale =
      case Integer.parse(to_string(t)) do
        {n, _} when is_integer(servings) and servings > 0 and n > 0 ->
          Decimal.div(Decimal.new(n), Decimal.new(servings))

        _ ->
          socket.assigns.scale
      end

    {:noreply, assign(socket, :scale, scale)}
  end

  defp load_meal(socket) do
    meal = Meals.get_meal_with_details!(socket.assigns.meal_id)
    options = Catalog.list_ingredients() |> Enum.map(&{&1.name, &1.id})

    socket
    |> assign(:page_title, meal.name)
    |> assign(:meal, meal)
    |> assign(:ingredient_options, options)
    |> assign(:line_form, to_form(Meals.change_meal_ingredient(%MealIngredient{})))
    |> assign(:nutrition, Meals.meal_nutrition(meal))
    |> assign(:nutrition_computed, Enum.any?(meal.meal_ingredients, & &1.grams))
  end

  defp format_qty(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)
  defp format_qty(other), do: other

  defp scale_qty(nil, _scale), do: nil
  defp scale_qty(%Decimal{} = q, scale), do: Decimal.mult(q, scale)

  defp scaled(nil, _scale), do: 0
  defp scaled(value, scale) when is_number(value), do: value * Decimal.to_float(scale)

  defp scaled?(scale), do: Decimal.compare(scale, Decimal.new(1)) != :eq

  # Highlight the quick button matching the current scale.
  defp scale_is?(scale, factor) do
    case Decimal.parse(factor) do
      {d, _} -> Decimal.compare(scale, d) == :eq
      :error -> false
    end
  end

  # Current target servings = base * scale, rounded to a whole number.
  defp current_target(servings, scale) do
    Decimal.new(servings) |> Decimal.mult(scale) |> Decimal.round(0) |> Decimal.to_integer()
  end
end
