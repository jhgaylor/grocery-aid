defmodule GroceryAid.Repo.Migrations.AddNutritionToIngredients do
  use Ecto.Migration

  # Per-100g energy from USDA FoodData Central, cached on the ingredient
  # (with the FDC id/description for provenance) so we only look it up once.
  def change do
    alter table(:ingredients) do
      add :calories_per_100g, :float
      add :fdc_id, :integer
      add :fdc_description, :string
    end
  end
end
