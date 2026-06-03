defmodule GroceryAid.CatalogTest do
  use GroceryAid.DataCase

  alias GroceryAid.Catalog

  describe "ingredients" do
    alias GroceryAid.Catalog.Ingredient

    import GroceryAid.CatalogFixtures

    @invalid_attrs %{name: nil, category: nil, default_unit: nil, notes: nil}

    test "list_ingredients/0 returns all ingredients" do
      ingredient = ingredient_fixture()
      assert Catalog.list_ingredients() == [ingredient]
    end

    test "get_ingredient!/1 returns the ingredient with given id" do
      ingredient = ingredient_fixture()
      assert Catalog.get_ingredient!(ingredient.id) == ingredient
    end

    test "create_ingredient/1 with valid data creates a ingredient" do
      valid_attrs = %{
        name: "some name",
        category: "some category",
        default_unit: "some default_unit",
        notes: "some notes"
      }

      assert {:ok, %Ingredient{} = ingredient} = Catalog.create_ingredient(valid_attrs)
      assert ingredient.name == "some name"
      assert ingredient.category == "some category"
      assert ingredient.default_unit == "some default_unit"
      assert ingredient.notes == "some notes"
    end

    test "create_ingredient/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_ingredient(@invalid_attrs)
    end

    test "update_ingredient/2 with valid data updates the ingredient" do
      ingredient = ingredient_fixture()

      update_attrs = %{
        name: "some updated name",
        category: "some updated category",
        default_unit: "some updated default_unit",
        notes: "some updated notes"
      }

      assert {:ok, %Ingredient{} = ingredient} =
               Catalog.update_ingredient(ingredient, update_attrs)

      assert ingredient.name == "some updated name"
      assert ingredient.category == "some updated category"
      assert ingredient.default_unit == "some updated default_unit"
      assert ingredient.notes == "some updated notes"
    end

    test "update_ingredient/2 with invalid data returns error changeset" do
      ingredient = ingredient_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_ingredient(ingredient, @invalid_attrs)
      assert ingredient == Catalog.get_ingredient!(ingredient.id)
    end

    test "delete_ingredient/1 deletes the ingredient" do
      ingredient = ingredient_fixture()
      assert {:ok, %Ingredient{}} = Catalog.delete_ingredient(ingredient)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_ingredient!(ingredient.id) end
    end

    test "change_ingredient/1 returns a ingredient changeset" do
      ingredient = ingredient_fixture()
      assert %Ecto.Changeset{} = Catalog.change_ingredient(ingredient)
    end
  end

  describe "stores" do
    alias GroceryAid.Catalog.Store

    import GroceryAid.CatalogFixtures

    @invalid_attrs %{name: nil, location: nil, url: nil, notes: nil}

    test "list_stores/0 returns all stores" do
      store = store_fixture()
      assert Catalog.list_stores() == [store]
    end

    test "get_store!/1 returns the store with given id" do
      store = store_fixture()
      assert Catalog.get_store!(store.id) == store
    end

    test "create_store/1 with valid data creates a store" do
      valid_attrs = %{
        name: "some name",
        location: "some location",
        url: "some url",
        notes: "some notes"
      }

      assert {:ok, %Store{} = store} = Catalog.create_store(valid_attrs)
      assert store.name == "some name"
      assert store.location == "some location"
      assert store.url == "some url"
      assert store.notes == "some notes"
    end

    test "create_store/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_store(@invalid_attrs)
    end

    test "update_store/2 with valid data updates the store" do
      store = store_fixture()

      update_attrs = %{
        name: "some updated name",
        location: "some updated location",
        url: "some updated url",
        notes: "some updated notes"
      }

      assert {:ok, %Store{} = store} = Catalog.update_store(store, update_attrs)
      assert store.name == "some updated name"
      assert store.location == "some updated location"
      assert store.url == "some updated url"
      assert store.notes == "some updated notes"
    end

    test "update_store/2 with invalid data returns error changeset" do
      store = store_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_store(store, @invalid_attrs)
      assert store == Catalog.get_store!(store.id)
    end

    test "delete_store/1 deletes the store" do
      store = store_fixture()
      assert {:ok, %Store{}} = Catalog.delete_store(store)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_store!(store.id) end
    end

    test "change_store/1 returns a store changeset" do
      store = store_fixture()
      assert %Ecto.Changeset{} = Catalog.change_store(store)
    end
  end
end
