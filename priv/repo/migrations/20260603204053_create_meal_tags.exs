defmodule GroceryAid.Repo.Migrations.CreateMealTags do
  use Ecto.Migration

  # Join table for the meals <-> tags many-to-many. One row per pairing;
  # both sides cascade on delete since the row is meaningless without them.
  def change do
    create table(:meal_tags) do
      add :meal_id, references(:meals, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meal_tags, [:meal_id])
    create index(:meal_tags, [:tag_id])
    create unique_index(:meal_tags, [:meal_id, :tag_id])
  end
end
