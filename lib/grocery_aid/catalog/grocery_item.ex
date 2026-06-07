defmodule GroceryAid.Catalog.GroceryItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Catalog.Store

  @categories ~w(produce meat seafood dairy bakery pantry frozen beverage snacks spices household other)

  schema "grocery_items" do
    field :name, :string
    field :category, :string
    field :notes, :string

    belongs_to :preferred_store, Store

    timestamps(type: :utc_datetime)
  end

  @doc "Allowed values for the `category` select."
  def categories, do: @categories

  @doc false
  def changeset(grocery_item, attrs) do
    grocery_item
    |> cast(attrs, [:name, :category, :notes, :preferred_store_id])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> assoc_constraint(:preferred_store)
    |> unique_constraint(:name, name: :grocery_items_lower_name_index)
  end
end
