defmodule GroceryAid.Meals.MealTag do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Meals.{Meal, Tag}

  schema "meal_tags" do
    belongs_to :meal, Meal
    belongs_to :tag, Tag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meal_tag, attrs) do
    meal_tag
    |> cast(attrs, [:meal_id, :tag_id])
    |> validate_required([:meal_id, :tag_id])
    |> assoc_constraint(:meal)
    |> assoc_constraint(:tag)
    |> unique_constraint([:meal_id, :tag_id],
      name: :meal_tags_meal_id_tag_id_index
    )
  end
end
