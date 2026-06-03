defmodule GroceryAid.MealsTest do
  use GroceryAid.DataCase

  alias GroceryAid.Meals

  describe "meals" do
    alias GroceryAid.Meals.Meal

    import GroceryAid.MealsFixtures

    @invalid_attrs %{
      name: nil,
      description: nil,
      source_url: nil,
      cuisine: nil,
      rating: nil,
      prep_minutes: nil,
      last_made_on: nil,
      notes: nil
    }

    test "list_meals/0 returns all meals" do
      meal = meal_fixture()
      assert Meals.list_meals() == [meal]
    end

    test "get_meal!/1 returns the meal with given id" do
      meal = meal_fixture()
      assert Meals.get_meal!(meal.id) == meal
    end

    test "create_meal/1 with valid data creates a meal" do
      valid_attrs = %{
        name: "some name",
        description: "some description",
        source_url: "some source_url",
        cuisine: "some cuisine",
        rating: 42,
        prep_minutes: 42,
        last_made_on: ~D[2026-06-02],
        notes: "some notes"
      }

      assert {:ok, %Meal{} = meal} = Meals.create_meal(valid_attrs)
      assert meal.name == "some name"
      assert meal.description == "some description"
      assert meal.source_url == "some source_url"
      assert meal.cuisine == "some cuisine"
      assert meal.rating == 42
      assert meal.prep_minutes == 42
      assert meal.last_made_on == ~D[2026-06-02]
      assert meal.notes == "some notes"
    end

    test "create_meal/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Meals.create_meal(@invalid_attrs)
    end

    test "update_meal/2 with valid data updates the meal" do
      meal = meal_fixture()

      update_attrs = %{
        name: "some updated name",
        description: "some updated description",
        source_url: "some updated source_url",
        cuisine: "some updated cuisine",
        rating: 43,
        prep_minutes: 43,
        last_made_on: ~D[2026-06-03],
        notes: "some updated notes"
      }

      assert {:ok, %Meal{} = meal} = Meals.update_meal(meal, update_attrs)
      assert meal.name == "some updated name"
      assert meal.description == "some updated description"
      assert meal.source_url == "some updated source_url"
      assert meal.cuisine == "some updated cuisine"
      assert meal.rating == 43
      assert meal.prep_minutes == 43
      assert meal.last_made_on == ~D[2026-06-03]
      assert meal.notes == "some updated notes"
    end

    test "update_meal/2 with invalid data returns error changeset" do
      meal = meal_fixture()
      assert {:error, %Ecto.Changeset{}} = Meals.update_meal(meal, @invalid_attrs)
      assert meal == Meals.get_meal!(meal.id)
    end

    test "delete_meal/1 deletes the meal" do
      meal = meal_fixture()
      assert {:ok, %Meal{}} = Meals.delete_meal(meal)
      assert_raise Ecto.NoResultsError, fn -> Meals.get_meal!(meal.id) end
    end

    test "change_meal/1 returns a meal changeset" do
      meal = meal_fixture()
      assert %Ecto.Changeset{} = Meals.change_meal(meal)
    end
  end
end
