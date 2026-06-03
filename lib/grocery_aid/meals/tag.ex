defmodule GroceryAid.Meals.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Meals.MealTag

  schema "tags" do
    field :name, :string

    has_many :meal_tags, MealTag
    has_many :meals, through: [:meal_tags, :meal]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> update_change(:name, fn n -> n |> String.trim() |> String.downcase() end)
    |> unique_constraint(:name, name: :tags_lower_name_index)
  end
end
