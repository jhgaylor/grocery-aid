defmodule GroceryAid.MealsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GroceryAid.Meals` context.
  """

  @doc """
  Generate a meal.
  """
  def meal_fixture(attrs \\ %{}) do
    {:ok, meal} =
      attrs
      |> Enum.into(%{
        cuisine: "some cuisine",
        description: "some description",
        last_made_on: ~D[2026-06-02],
        name: "some name",
        notes: "some notes",
        prep_minutes: 42,
        rating: 42,
        source_url: "some source_url"
      })
      |> GroceryAid.Meals.create_meal()

    meal
  end
end
