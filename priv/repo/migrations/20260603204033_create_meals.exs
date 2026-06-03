defmodule GroceryAid.Repo.Migrations.CreateMeals do
  use Ecto.Migration

  def change do
    create table(:meals) do
      add :name, :string, null: false
      add :description, :text
      add :source_url, :string
      add :cuisine, :string
      add :rating, :integer
      add :prep_minutes, :integer
      add :last_made_on, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end
  end
end
