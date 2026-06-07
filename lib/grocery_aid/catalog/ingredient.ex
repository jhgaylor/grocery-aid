defmodule GroceryAid.Catalog.Ingredient do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Catalog.{Store, StoreItem}
  alias GroceryAid.Meals.MealIngredient

  @categories ~w(produce meat seafood dairy bakery pantry frozen beverage spices household other)

  schema "ingredients" do
    field :name, :string
    field :category, :string
    field :default_unit, :string
    field :notes, :string
    field :calories_per_100g, :float
    field :fdc_id, :integer
    field :fdc_description, :string

    belongs_to :preferred_store, Store

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
    |> cast(attrs, [
      :name,
      :category,
      :default_unit,
      :notes,
      :calories_per_100g,
      :fdc_id,
      :fdc_description,
      :preferred_store_id
    ])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> nilify_blank(:category)
    |> validate_inclusion(:category, @categories)
    |> assoc_constraint(:preferred_store)
    |> unique_constraint(:name, name: :ingredients_lower_name_index)
  end

  defp nilify_blank(changeset, field) do
    case get_change(changeset, field) do
      "" -> put_change(changeset, field, nil)
      _ -> changeset
    end
  end
end
