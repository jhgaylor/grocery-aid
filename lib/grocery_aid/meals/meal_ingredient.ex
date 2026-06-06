defmodule GroceryAid.Meals.MealIngredient do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Catalog.Ingredient
  alias GroceryAid.Meals.Meal

  schema "meal_ingredients" do
    field :quantity, :decimal
    field :unit, :string
    field :notes, :string
    field :grams, :float

    belongs_to :meal, Meal
    belongs_to :ingredient, Ingredient

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meal_ingredient, attrs) do
    meal_ingredient
    |> cast(attrs, [:quantity, :unit, :notes, :grams, :meal_id, :ingredient_id])
    |> validate_required([:meal_id, :ingredient_id])
    |> validate_number(:quantity, greater_than: 0)
    |> assoc_constraint(:meal)
    |> assoc_constraint(:ingredient)
    |> unique_constraint([:meal_id, :ingredient_id],
      name: :meal_ingredients_meal_id_ingredient_id_index,
      message: "is already in this meal"
    )
  end
end
