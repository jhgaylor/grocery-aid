defmodule GroceryAid.Repo.Migrations.CreateStores do
  use Ecto.Migration

  def change do
    create table(:stores) do
      add :name, :string, null: false
      add :location, :string
      add :url, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stores, ["lower(name)"], name: :stores_lower_name_index)
  end
end
