defmodule GroceryAid.Repo.Migrations.AddGramsToMealIngredients do
  use Ecto.Migration

  # Estimated edible weight of this recipe line, used with the ingredient's
  # calories_per_100g to compute the line's calories. Filled by
  # Meals.calculate_nutrition/1 (deterministic for mass units, LLM otherwise).
  def change do
    alter table(:meal_ingredients) do
      add :grams, :float
    end
  end
end
