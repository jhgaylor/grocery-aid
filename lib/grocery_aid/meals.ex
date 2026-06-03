defmodule GroceryAid.Meals do
  @moduledoc """
  The Meals context.
  """

  import Ecto.Query, warn: false
  alias GroceryAid.Repo

  alias GroceryAid.Meals.Meal

  @doc """
  Lists meals (tags preloaded). Options:
    * `:tag`  — only meals carrying this tag name
    * `:sort` — `:name` (default), `:rating` (best first), `:recent` (most
      recently made first, never-made last)
  """
  def list_meals(opts \\ []) do
    query = from(m in Meal, distinct: true, preload: [:tags])

    query =
      case opts[:tag] do
        tag when is_binary(tag) and tag != "" ->
          from m in query, join: t in assoc(m, :tags), where: t.name == ^tag

        _ ->
          query
      end

    query
    |> sort_meals(opts[:sort])
    |> Repo.all()
  end

  defp sort_meals(q, :rating),
    do: from(m in q, order_by: [desc_nulls_last: m.rating, asc: m.name])

  defp sort_meals(q, :recent),
    do: from(m in q, order_by: [desc_nulls_last: m.last_made_on, asc: m.name])

  defp sort_meals(q, _), do: from(m in q, order_by: [asc: m.name])

  @doc "Stamps a meal as made on the given date (defaults to today)."
  def mark_made(%Meal{} = meal, date \\ Date.utc_today()) do
    update_meal(meal, %{last_made_on: date})
  end

  @doc "Counts all meals."
  def count_meals, do: Repo.aggregate(Meal, :count)

  @doc """
  Returns up to `n` random meals (with tags preloaded) — the antidote to
  "I always eat the same three things." Powers the dashboard suggestion.
  Optionally restricted to meals carrying `tag`.
  """
  def suggest_meals(n \\ 3, tag \\ nil) do
    query = from(m in Meal, order_by: fragment("RANDOM()"), limit: ^n, preload: [:tags])

    query =
      if is_binary(tag) and tag != "",
        do: from(m in query, join: t in assoc(m, :tags), where: t.name == ^tag),
        else: query

    Repo.all(query)
  end

  @doc "Gets a single meal. Raises `Ecto.NoResultsError` if it does not exist."
  def get_meal!(id), do: Repo.get!(Meal, id)

  @doc """
  Gets a meal with its recipe lines (each with its ingredient) and tags
  preloaded — everything the show page needs in one query batch.
  """
  def get_meal_with_details!(id) do
    Meal
    |> Repo.get!(id)
    |> Repo.preload([:tags, meal_ingredients: [:ingredient]])
  end

  @doc """
  Creates a meal.

  ## Examples

      iex> create_meal(%{field: value})
      {:ok, %Meal{}}

      iex> create_meal(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_meal(attrs) do
    %Meal{}
    |> Meal.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a meal.

  ## Examples

      iex> update_meal(meal, %{field: new_value})
      {:ok, %Meal{}}

      iex> update_meal(meal, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_meal(%Meal{} = meal, attrs) do
    meal
    |> Meal.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a meal.

  ## Examples

      iex> delete_meal(meal)
      {:ok, %Meal{}}

      iex> delete_meal(meal)
      {:error, %Ecto.Changeset{}}

  """
  def delete_meal(%Meal{} = meal) do
    Repo.delete(meal)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking meal changes.

  ## Examples

      iex> change_meal(meal)
      %Ecto.Changeset{data: %Meal{}}

  """
  def change_meal(%Meal{} = meal, attrs \\ %{}) do
    Meal.changeset(meal, attrs)
  end

  ## Recipe lines (meal_ingredients) ----------------------------------------

  alias GroceryAid.Meals.MealIngredient

  def get_meal_ingredient!(id) do
    Repo.get!(MealIngredient, id) |> Repo.preload([:ingredient, :meal])
  end

  def add_meal_ingredient(%Meal{} = meal, attrs) do
    %MealIngredient{meal_id: meal.id}
    |> MealIngredient.changeset(attrs)
    |> Repo.insert()
  end

  def update_meal_ingredient(%MealIngredient{} = mi, attrs) do
    mi
    |> MealIngredient.changeset(attrs)
    |> Repo.update()
  end

  def delete_meal_ingredient(%MealIngredient{} = mi), do: Repo.delete(mi)

  def change_meal_ingredient(%MealIngredient{} = mi, attrs \\ %{}) do
    MealIngredient.changeset(mi, attrs)
  end

  @doc """
  Creates a meal from an imported recipe in one transaction: the meal itself,
  then one recipe line per `ingredient_lines` entry (`%{name, quantity, unit}`),
  matching/creating each ingredient by name. Bad lines are skipped, not fatal.
  """
  def create_imported_meal(meal_attrs, ingredient_lines) do
    Repo.transaction(fn ->
      meal =
        case create_meal(meal_attrs) do
          {:ok, meal} -> meal
          {:error, changeset} -> Repo.rollback(changeset)
        end

      Enum.each(ingredient_lines, fn line ->
        with {:ok, ingredient} <- GroceryAid.Catalog.get_or_create_ingredient(line.name) do
          add_meal_ingredient(meal, %{
            ingredient_id: ingredient.id,
            quantity: line[:quantity],
            unit: line[:unit]
          })
        end
      end)

      meal
    end)
  end

  ## Tags --------------------------------------------------------------------

  alias GroceryAid.Meals.{MealTag, Tag}

  def list_tags do
    Tag |> order_by(asc: :name) |> Repo.all()
  end

  @doc """
  Fetches a tag by (normalized) name, creating it if it doesn't exist yet.
  """
  def get_or_create_tag(name) when is_binary(name) do
    normalized = name |> String.trim() |> String.downcase()

    case Repo.get_by(Tag, name: normalized) do
      nil -> %Tag{} |> Tag.changeset(%{name: normalized}) |> Repo.insert()
      %Tag{} = tag -> {:ok, tag}
    end
  end

  @doc """
  Replaces a meal's tag set from a comma-separated string (e.g. "thai, dinner,
  quick"). Unknown tags are created; the meal_tags join is reconciled.
  """
  def set_meal_tags(%Meal{} = meal, tag_string) when is_binary(tag_string) do
    names =
      tag_string
      |> String.split(",")
      |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    tags =
      Enum.map(names, fn n ->
        {:ok, tag} = get_or_create_tag(n)
        tag
      end)

    Repo.delete_all(from mt in MealTag, where: mt.meal_id == ^meal.id)

    Enum.each(tags, fn tag ->
      %MealTag{}
      |> MealTag.changeset(%{meal_id: meal.id, tag_id: tag.id})
      |> Repo.insert()
    end)

    {:ok, Repo.preload(meal, :tags, force: true)}
  end

  ## Shopping list -----------------------------------------------------------

  @doc """
  Given a list of meal ids, aggregates their recipe lines into a shopping
  list grouped by store. Quantities for the same ingredient are summed per
  unit (you can't add "2 cups" to "1 lb", so each unit is tracked separately).
  Each ingredient also carries the cheapest known store_item so the list can
  suggest where to buy it; ingredients with no known store land in an
  "Unassigned" bucket.

  Returns `[%{store: store | nil, items: [%{ingredient:, store_item:, quantities:}]}]`
  where `quantities` is `[%{unit: string | nil, total: Decimal}]`.
  """
  def shopping_list(meal_ids) when is_list(meal_ids) do
    alias GroceryAid.Catalog.StoreItem

    lines =
      from(mi in MealIngredient, where: mi.meal_id in ^meal_ids, preload: [:ingredient])
      |> Repo.all()

    by_ingredient = Enum.group_by(lines, & &1.ingredient_id)
    ingredient_ids = Map.keys(by_ingredient)

    # Cheapest store_item per ingredient (nil price sorts last).
    store_items =
      from(si in StoreItem, where: si.ingredient_id in ^ingredient_ids, preload: [:store])
      |> Repo.all()
      |> Enum.group_by(& &1.ingredient_id)
      |> Map.new(fn {ing_id, items} ->
        {ing_id, Enum.min_by(items, &(&1.price || Decimal.new("999999999")), fn -> nil end)}
      end)

    by_ingredient
    |> Enum.map(fn {ing_id, ing_lines} ->
      %{
        ingredient: hd(ing_lines).ingredient,
        store_item: Map.get(store_items, ing_id),
        quantities: aggregate_quantities(ing_lines)
      }
    end)
    |> Enum.sort_by(& &1.ingredient.name)
    |> Enum.group_by(fn %{store_item: si} -> si && si.store end)
    |> Enum.map(fn {store, items} -> %{store: store, items: items} end)
    |> Enum.sort_by(fn %{store: store} -> (store && store.name) || "~" end)
  end

  @doc """
  Renders aggregated quantities (`[%{unit, total}]`) as a short string like
  `"2 cups + 1 tbsp"`, or `""` when nothing has a quantity.
  """
  def format_quantities([]), do: ""

  def format_quantities(quantities) do
    quantities
    |> Enum.map(fn %{unit: unit, total: total} ->
      [format_decimal(total), unit] |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" ")
    end)
    |> Enum.join(" + ")
  end

  defp format_decimal(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)
  defp format_decimal(other), do: to_string(other)

  @doc """
  Formats a `shopping_list/1` result as plaintext grouped by store — for the
  "copy to take to the store" affordance.
  """
  def shopping_list_text(groups) do
    groups
    |> Enum.map(fn %{store: store, items: items} ->
      header = (store && store.name) || "No store assigned"

      rows =
        Enum.map(items, fn item ->
          qty = format_quantities(item.quantities)
          "- " <> if(qty == "", do: "", else: qty <> " ") <> item.ingredient.name
        end)

      Enum.join([header | rows], "\n")
    end)
    |> Enum.join("\n\n")
  end

  # Sum quantities per unit; lines without a quantity contribute nothing.
  defp aggregate_quantities(lines) do
    lines
    |> Enum.filter(& &1.quantity)
    |> Enum.group_by(& &1.unit)
    |> Enum.map(fn {unit, ls} ->
      total = Enum.reduce(ls, Decimal.new(0), &Decimal.add(&2, &1.quantity))
      %{unit: unit, total: total}
    end)
    |> Enum.sort_by(&(&1.unit || ""))
  end
end
