defmodule GroceryAid.Catalog.StoreItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Catalog.{Ingredient, Store}

  schema "store_items" do
    field :price, :decimal
    field :unit, :string
    field :aisle, :string
    field :product_url, :string
    field :notes, :string

    belongs_to :ingredient, Ingredient
    belongs_to :store, Store

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(store_item, attrs) do
    store_item
    |> cast(attrs, [:price, :unit, :aisle, :product_url, :notes, :ingredient_id, :store_id])
    |> validate_required([:ingredient_id, :store_id])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> assoc_constraint(:ingredient)
    |> assoc_constraint(:store)
    |> unique_constraint([:ingredient_id, :store_id],
      name: :store_items_ingredient_id_store_id_index,
      message: "this ingredient is already linked to that store"
    )
  end
end
