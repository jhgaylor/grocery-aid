defmodule GroceryAid.Repo.Migrations.AddPreferredStoreToIngredients do
  use Ecto.Migration

  # Optional "where I prefer to buy this" per ingredient — the grouping key for
  # the shopping list and the "I'm shopping at X" filter. Distinct from
  # store_items (which catalog availability + price). nilify on store delete so
  # removing a store doesn't take ingredients with it.
  def change do
    alter table(:ingredients) do
      add :preferred_store_id, references(:stores, on_delete: :nilify_all)
    end

    create index(:ingredients, [:preferred_store_id])
  end
end
