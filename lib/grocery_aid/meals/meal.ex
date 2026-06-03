defmodule GroceryAid.Meals.Meal do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Meals.{MealIngredient, MealTag}

  schema "meals" do
    field :name, :string
    field :description, :string
    field :source_url, :string
    field :cuisine, :string
    field :rating, :integer
    field :prep_minutes, :integer
    field :last_made_on, :date
    field :notes, :string

    has_many :meal_ingredients, MealIngredient
    has_many :ingredients, through: [:meal_ingredients, :ingredient]
    has_many :meal_tags, MealTag
    has_many :tags, through: [:meal_tags, :tag]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meal, attrs) do
    meal
    |> cast(attrs, [
      :name,
      :description,
      :source_url,
      :cuisine,
      :rating,
      :prep_minutes,
      :last_made_on,
      :notes
    ])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> validate_inclusion(:rating, 1..5, message: "must be between 1 and 5")
    |> validate_number(:prep_minutes, greater_than_or_equal_to: 0)
  end
end
