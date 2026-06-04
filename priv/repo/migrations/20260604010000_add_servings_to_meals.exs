defmodule GroceryAid.Repo.Migrations.AddServingsToMeals do
  use Ecto.Migration

  # `servings` is the yield the stored ingredient quantities correspond to
  # (e.g. an imported recipe "makes 8 sandwiches" → 8). Scaling on the meal
  # page and shopping list is computed as target/servings. Nullable: meals
  # without a known yield just don't scale.
  def change do
    alter table(:meals) do
      add :servings, :integer
    end
  end
end
