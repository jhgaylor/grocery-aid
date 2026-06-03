defmodule GroceryAid.Repo.Migrations.CreateTags do
  use Ecto.Migration

  # Free-form labels for meals: cuisine (thai, mexican), meal slot
  # (breakfast, dinner), or dietary (vegetarian, quick). Names are unique
  # case-insensitively so "Thai" and "thai" don't both exist.
  def change do
    create table(:tags) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, ["lower(name)"], name: :tags_lower_name_index)
  end
end
