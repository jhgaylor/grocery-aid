defmodule GroceryAid.Repo.Migrations.CreateMealIngredients do
  use Ecto.Migration

  # The recipe line items: each row is one ingredient used in one meal,
  # with a quantity + unit. Deleting a meal removes its lines; deleting an
  # ingredient that's still referenced is blocked (restrict) so we never
  # silently drop a recipe component.
  def change do
    create table(:meal_ingredients) do
      add :quantity, :decimal
      add :unit, :string
      add :notes, :string
      add :meal_id, references(:meals, on_delete: :delete_all), null: false
      add :ingredient_id, references(:ingredients, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:meal_ingredients, [:meal_id])
    create index(:meal_ingredients, [:ingredient_id])
    create unique_index(:meal_ingredients, [:meal_id, :ingredient_id])
  end
end
