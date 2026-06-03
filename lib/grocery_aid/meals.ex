defmodule GroceryAid.Meals do
  @moduledoc """
  The Meals context.
  """

  import Ecto.Query, warn: false
  alias GroceryAid.Repo

  alias GroceryAid.Meals.Meal

  @doc """
  Returns the list of meals.

  ## Examples

      iex> list_meals()
      [%Meal{}, ...]

  """
  def list_meals do
    Meal
    |> order_by(asc: :name)
    |> preload(:tags)
    |> Repo.all()
  end

  @doc """
  Gets a single meal.

  Raises `Ecto.NoResultsError` if the Meal does not exist.

  ## Examples

      iex> get_meal!(123)
      %Meal{}

      iex> get_meal!(456)
      ** (Ecto.NoResultsError)

  """
  def count_meals, do: Repo.aggregate(Meal, :count)

  @doc """
  Returns up to `n` random meals (with tags preloaded) — the antidote to
  "I always eat the same three things." Powers the dashboard suggestion.
  """
  def suggest_meals(n \\ 3) do
    Meal
    |> order_by(fragment("RANDOM()"))
    |> limit(^n)
    |> preload(:tags)
    |> Repo.all()
  end

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
  Given a list of meal ids, aggregates their ingredients into a shopping
  list grouped by store. For each ingredient we attach the cheapest known
  store_item (if any) so the list can suggest where to buy it. Ingredients
  with no known store land in an "Unassigned" bucket.

  Returns a list of `%{store: store | nil, items: [%{ingredient:, store_item:}]}`.
  """
  def shopping_list(meal_ids) when is_list(meal_ids) do
    alias GroceryAid.Catalog.{Ingredient, StoreItem}

    ingredients =
      from(mi in MealIngredient,
        where: mi.meal_id in ^meal_ids,
        join: i in assoc(mi, :ingredient),
        distinct: i.id,
        select: i,
        order_by: i.name
      )
      |> Repo.all()

    ingredient_ids = Enum.map(ingredients, & &1.id)

    # Cheapest store_item per ingredient (nil price sorts last).
    store_items =
      from(si in StoreItem,
        where: si.ingredient_id in ^ingredient_ids,
        preload: [:store]
      )
      |> Repo.all()
      |> Enum.group_by(& &1.ingredient_id)
      |> Map.new(fn {ing_id, items} ->
        cheapest =
          Enum.min_by(items, fn si -> si.price || Decimal.new("999999999") end, fn -> nil end)

        {ing_id, cheapest}
      end)

    ingredients
    |> Enum.map(fn %Ingredient{} = ing ->
      %{ingredient: ing, store_item: Map.get(store_items, ing.id)}
    end)
    |> Enum.group_by(fn %{store_item: si} -> si && si.store end)
    |> Enum.map(fn {store, items} -> %{store: store, items: items} end)
    |> Enum.sort_by(fn %{store: store} -> (store && store.name) || "~" end)
  end
end
