defmodule GroceryAidWeb.RecipeComponents do
  @moduledoc """
  Shared UI + param helpers for the recipe import and generate flows. Both end
  in the same editable preview (meal fields + ingredient lines + tags) and the
  same create payload, so that lives here once.
  """
  use GroceryAidWeb, :html

  @doc """
  Editable recipe preview form. The host LiveView handles `phx-submit="create"`
  and `phx-click="back"`.

  Assigns:
    * `:meal` — map with `:name`, `:cuisine`, `:servings`, `:description`, and
      optionally `:source_url` / `:prep_minutes`
    * `:lines` — enriched ingredient lines (see `GroceryAid.Recipes.Lines`)
    * `:tags_value` — comma-separated tag string (default "")
    * `:enhanced` — show the "AI-matched" badge (default false)
    * `:submit_label` — primary button text
  """
  attr :meal, :map, required: true
  attr :lines, :list, required: true
  attr :tags_value, :string, default: ""
  attr :enhanced, :boolean, default: false
  attr :submit_label, :string, default: "Create meal"

  def recipe_preview(assigns) do
    ~H"""
    <.form for={%{}} id="recipe-form" phx-submit="create">
      <.input name="meal[name]" value={@meal.name} type="text" label="Meal name" />
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <.input name="meal[cuisine]" value={@meal.cuisine} type="text" label="Cuisine" />
        <.input name="meal[servings]" value={@meal.servings} type="number" label="Makes (servings)" />
      </div>
      <input
        :if={Map.get(@meal, :source_url)}
        type="hidden"
        name="meal[source_url]"
        value={@meal.source_url}
      />
      <input
        :if={Map.get(@meal, :prep_minutes)}
        type="hidden"
        name="meal[prep_minutes]"
        value={@meal.prep_minutes}
      />
      <.input name="meal[description]" value={@meal.description} type="textarea" label="Description" />
      <.input
        name="tags"
        value={@tags_value}
        type="text"
        label="Tags"
        placeholder="dinner, italian (comma separated)"
      />

      <div class="card bg-base-200 mt-4">
        <div class="card-body">
          <h2 class="card-title text-base">
            Ingredients <span class="badge badge-sm">{length(@lines)}</span>
            <span :if={@enhanced} class="badge badge-sm badge-primary badge-outline gap-1">
              <.icon name="hero-sparkles" class="size-3" /> AI
            </span>
          </h2>
          <p class="text-xs opacity-60">
            Untick lines you don't want.
            <span class="badge badge-xs badge-info badge-outline">→ name</span>
            matched an ingredient you have;
            <span class="badge badge-xs badge-success badge-outline">new</span>
            ones get added.
          </p>

          <div :for={{line, idx} <- Enum.with_index(@lines)} class="flex items-center gap-2 py-1">
            <input
              type="checkbox"
              name={"lines[#{idx}][include]"}
              value="true"
              checked
              class="checkbox checkbox-sm"
            />
            <input type="hidden" name={"lines[#{idx}][quantity]"} value={fmt_qty(line.quantity)} />
            <input type="hidden" name={"lines[#{idx}][unit]"} value={line.unit} />
            <input type="hidden" name={"lines[#{idx}][matched_id]"} value={line.matched_id} />
            <input type="hidden" name={"lines[#{idx}][category]"} value={line.category} />
            <span class="text-sm opacity-70 w-24 shrink-0 text-right">
              {fmt_qty(line.quantity)} {line.unit}
            </span>
            <input
              type="text"
              name={"lines[#{idx}][name]"}
              value={line.name}
              class="input input-sm input-bordered flex-1"
            />
            <span :if={line.matched_id} class="badge badge-xs badge-info badge-outline shrink-0">
              → {line.matched_name}
            </span>
            <span
              :if={is_nil(line.matched_id)}
              class="badge badge-xs badge-success badge-outline shrink-0"
            >
              new{if line.category, do: " · #{line.category}"}
            </span>
          </div>
        </div>
      </div>

      <footer class="mt-4 flex gap-2">
        <.button variant="primary" phx-disable-with="Saving...">
          <.icon name="hero-check" class="size-4" /> {@submit_label}
        </.button>
        <.button type="button" phx-click="back">Back</.button>
        <a
          :if={Map.get(@meal, :source_url)}
          href={@meal.source_url}
          target="_blank"
          rel="noopener"
          class="btn btn-ghost"
        >
          View original
        </a>
      </footer>
    </.form>
    """
  end

  @doc """
  Turns the `create` form params into the line list `create_imported_meal/2`
  wants: included lines only, using a confirmed `:ingredient_id` when matched,
  else `:name` (+ `:category`) to match/create by name.
  """
  def lines_from_params(params) do
    params
    |> Map.get("lines", %{})
    |> Map.values()
    |> Enum.filter(&(&1["include"] == "true"))
    |> Enum.map(&to_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp to_line(l) do
    name = String.trim(l["name"] || "")
    base = %{quantity: blank_to_nil(l["quantity"]), unit: blank_to_nil(l["unit"])}

    case blank_to_nil(l["matched_id"]) do
      nil when name == "" -> nil
      nil -> Map.merge(base, %{name: name, category: blank_to_nil(l["category"])})
      id -> Map.put(base, :ingredient_id, String.to_integer(id))
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s

  defp fmt_qty(nil), do: ""
  defp fmt_qty(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)
  defp fmt_qty(other), do: to_string(other)
end
