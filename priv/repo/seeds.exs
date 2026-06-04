# Seeds a small starter catalog so a fresh deploy isn't a blank page.
# Idempotent: safe to run on every container start (the Release task calls
# it after migrate). Uses get_or_create semantics keyed on names.

alias GroceryAid.{Catalog, Meals}
alias GroceryAid.Repo

upsert = fn module, key, attrs ->
  query_val = Map.fetch!(attrs, key)

  case Repo.get_by(module, [{key, query_val}]) do
    nil ->
      module
      |> struct()
      |> module.changeset(attrs)
      |> Repo.insert!()

    existing ->
      existing
  end
end

# --- Stores ---------------------------------------------------------------
stores =
  for s <- [
        %{name: "Trader Joe's", location: "Neighborhood", url: "https://www.traderjoes.com"},
        %{name: "Costco", location: "Warehouse", url: "https://www.costco.com"},
        %{name: "Whole Foods", location: "Uptown", url: "https://www.wholefoodsmarket.com"}
      ],
      into: %{} do
    {s.name, upsert.(Catalog.Store, :name, s)}
  end

# --- Ingredients ----------------------------------------------------------
ingredients =
  for i <- [
        %{name: "chicken breast", category: "meat", default_unit: "lb"},
        %{name: "basmati rice", category: "pantry", default_unit: "lb"},
        %{name: "yellow onion", category: "produce", default_unit: "each"},
        %{name: "garlic", category: "produce", default_unit: "clove"},
        %{name: "olive oil", category: "pantry", default_unit: "bottle"},
        %{name: "canned chickpeas", category: "pantry", default_unit: "can"},
        %{name: "baby spinach", category: "produce", default_unit: "bag"},
        %{name: "coconut milk", category: "pantry", default_unit: "can"},
        %{name: "curry paste", category: "spices", default_unit: "jar"},
        %{name: "eggs", category: "dairy", default_unit: "dozen"}
      ],
      into: %{} do
    {i.name, upsert.(Catalog.Ingredient, :name, i)}
  end

# --- Where to buy a few of them (store_items) -----------------------------
links = [
  {"chicken breast", "Costco", %{price: "3.99", unit: "lb", aisle: "Meat"}},
  {"basmati rice", "Costco", %{price: "12.99", unit: "10 lb", aisle: "Dry goods"}},
  {"olive oil", "Trader Joe's", %{price: "7.99", unit: "bottle", aisle: "3"}},
  {"baby spinach", "Trader Joe's", %{price: "2.49", unit: "bag", aisle: "Produce"}},
  {"coconut milk", "Whole Foods", %{price: "1.99", unit: "can", aisle: "International"}},
  {"curry paste", "Whole Foods", %{price: "4.49", unit: "jar", aisle: "International"}}
]

for {ing_name, store_name, attrs} <- links do
  ing = ingredients[ing_name]
  store = stores[store_name]

  unless Repo.get_by(Catalog.StoreItem, ingredient_id: ing.id, store_id: store.id) do
    attrs
    |> Map.merge(%{ingredient_id: ing.id, store_id: store.id})
    |> then(&Catalog.create_store_item/1)
  end
end

# --- Meals ----------------------------------------------------------------
meal_specs = [
  %{
    meal: %{
      name: "Coconut chicken curry",
      cuisine: "Thai",
      rating: 5,
      prep_minutes: 35,
      servings: 4,
      description: "Weeknight curry over rice."
    },
    tags: "dinner, thai, quick",
    ingredients: [
      {"chicken breast", "1.5", "lb"},
      {"coconut milk", "1", "can"},
      {"curry paste", "2", "tbsp"},
      {"basmati rice", "2", "cup"},
      {"yellow onion", "1", "each"}
    ]
  },
  %{
    meal: %{
      name: "Chickpea spinach skillet",
      cuisine: "Mediterranean",
      rating: 4,
      prep_minutes: 20,
      servings: 2,
      description: "Fast vegetarian skillet."
    },
    tags: "dinner, vegetarian, quick",
    ingredients: [
      {"canned chickpeas", "2", "can"},
      {"baby spinach", "1", "bag"},
      {"garlic", "3", "clove"},
      {"olive oil", "2", "tbsp"}
    ]
  }
]

for %{meal: meal_attrs, tags: tags, ingredients: lines} <- meal_specs do
  meal = upsert.(Meals.Meal, :name, meal_attrs)
  {:ok, meal} = Meals.set_meal_tags(meal, tags)

  for {ing_name, qty, unit} <- lines do
    ing = ingredients[ing_name]

    unless Repo.get_by(Meals.MealIngredient, meal_id: meal.id, ingredient_id: ing.id) do
      Meals.add_meal_ingredient(meal, %{ingredient_id: ing.id, quantity: qty, unit: unit})
    end
  end
end

IO.puts(
  "Seeded #{Meals.count_meals()} meals, #{Catalog.count_ingredients()} ingredients, #{Catalog.count_stores()} stores."
)
