defmodule GroceryAid.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GroceryAid.Catalog` context.
  """

  @doc """
  Generate a ingredient.
  """
  def ingredient_fixture(attrs \\ %{}) do
    {:ok, ingredient} =
      attrs
      |> Enum.into(%{
        category: "some category",
        default_unit: "some default_unit",
        name: "some name",
        notes: "some notes"
      })
      |> GroceryAid.Catalog.create_ingredient()

    ingredient
  end

  @doc """
  Generate a store.
  """
  def store_fixture(attrs \\ %{}) do
    {:ok, store} =
      attrs
      |> Enum.into(%{
        location: "some location",
        name: "some name",
        notes: "some notes",
        url: "some url"
      })
      |> GroceryAid.Catalog.create_store()

    store
  end
end
