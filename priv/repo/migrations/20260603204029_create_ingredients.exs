defmodule GroceryAid.Repo.Migrations.CreateIngredients do
  use Ecto.Migration

  def change do
    create table(:ingredients) do
      add :name, :string, null: false
      add :category, :string
      add :default_unit, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ingredients, ["lower(name)"], name: :ingredients_lower_name_index)
  end
end
