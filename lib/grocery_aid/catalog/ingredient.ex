defmodule GroceryAid.Catalog.Ingredient do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Catalog.StoreItem
  alias GroceryAid.Meals.MealIngredient

  @categories ~w(produce meat seafood dairy bakery pantry frozen beverage spices household other)

  schema "ingredients" do
    field :name, :string
    field :category, :string
    field :default_unit, :string
    field :notes, :string

    has_many :store_items, StoreItem
    has_many :meal_ingredients, MealIngredient
    has_many :stores, through: [:store_items, :store]

    timestamps(type: :utc_datetime)
  end

  @doc "Allowed values for the `category` select."
  def categories, do: @categories

  @doc false
  def changeset(ingredient, attrs) do
    ingredient
    |> cast(attrs, [:name, :category, :default_unit, :notes])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> nilify_blank(:category)
    |> validate_inclusion(:category, @categories)
    |> unique_constraint(:name, name: :ingredients_lower_name_index)
  end

  defp nilify_blank(changeset, field) do
    case get_change(changeset, field) do
      "" -> put_change(changeset, field, nil)
      _ -> changeset
    end
  end
end
