defmodule GroceryAid.Catalog.Store do
  use Ecto.Schema
  import Ecto.Changeset

  alias GroceryAid.Catalog.StoreItem

  schema "stores" do
    field :name, :string
    field :location, :string
    field :url, :string
    field :notes, :string

    has_many :store_items, StoreItem
    has_many :ingredients, through: [:store_items, :ingredient]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(store, attrs) do
    store
    |> cast(attrs, [:name, :location, :url, :notes])
    |> validate_required([:name])
    |> update_change(:name, &String.trim/1)
    |> unique_constraint(:name, name: :stores_lower_name_index)
  end
end
