defmodule GroceryAid.Repo.Migrations.CreateStoreItems do
  use Ecto.Migration

  # A store_item records that a given ingredient can be bought at a given
  # store — with the price, package unit, aisle, and a product URL we can
  # link out to (or later import from). One row per (ingredient, store).
  def change do
    create table(:store_items) do
      add :price, :decimal
      add :unit, :string
      add :aisle, :string
      add :product_url, :string
      add :notes, :text
      add :ingredient_id, references(:ingredients, on_delete: :delete_all), null: false
      add :store_id, references(:stores, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:store_items, [:ingredient_id])
    create index(:store_items, [:store_id])
    create unique_index(:store_items, [:ingredient_id, :store_id])
  end
end
