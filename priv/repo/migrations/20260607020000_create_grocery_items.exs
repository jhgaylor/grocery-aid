defmodule GroceryAid.Repo.Migrations.CreateGroceryItems do
  use Ecto.Migration

  # Standalone things you buy that aren't recipe ingredients — cookies, cereal,
  # paper towels. They carry a preferred store so they slot into the same
  # store-grouped shopping list, and you tick the ones you want per trip.
  def change do
    create table(:grocery_items) do
      add :name, :string, null: false
      add :category, :string
      add :notes, :string
      add :preferred_store_id, references(:stores, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:grocery_items, ["lower(name)"], name: :grocery_items_lower_name_index)
    create index(:grocery_items, [:preferred_store_id])
  end
end
