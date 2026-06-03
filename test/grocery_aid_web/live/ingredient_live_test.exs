defmodule GroceryAidWeb.IngredientLiveTest do
  use GroceryAidWeb.ConnCase

  import Phoenix.LiveViewTest
  import GroceryAid.CatalogFixtures

  @create_attrs %{
    name: "some name",
    category: "some category",
    default_unit: "some default_unit",
    notes: "some notes"
  }
  @update_attrs %{
    name: "some updated name",
    category: "some updated category",
    default_unit: "some updated default_unit",
    notes: "some updated notes"
  }
  @invalid_attrs %{name: nil, category: nil, default_unit: nil, notes: nil}
  defp create_ingredient(_) do
    ingredient = ingredient_fixture()

    %{ingredient: ingredient}
  end

  describe "Index" do
    setup [:create_ingredient]

    test "lists all ingredients", %{conn: conn, ingredient: ingredient} do
      {:ok, _index_live, html} = live(conn, ~p"/ingredients")

      assert html =~ "Listing Ingredients"
      assert html =~ ingredient.name
    end

    test "saves new ingredient", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/ingredients")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Ingredient")
               |> render_click()
               |> follow_redirect(conn, ~p"/ingredients/new")

      assert render(form_live) =~ "New Ingredient"

      assert form_live
             |> form("#ingredient-form", ingredient: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#ingredient-form", ingredient: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/ingredients")

      html = render(index_live)
      assert html =~ "Ingredient created successfully"
      assert html =~ "some name"
    end

    test "updates ingredient in listing", %{conn: conn, ingredient: ingredient} do
      {:ok, index_live, _html} = live(conn, ~p"/ingredients")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#ingredients-#{ingredient.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/ingredients/#{ingredient}/edit")

      assert render(form_live) =~ "Edit Ingredient"

      assert form_live
             |> form("#ingredient-form", ingredient: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#ingredient-form", ingredient: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/ingredients")

      html = render(index_live)
      assert html =~ "Ingredient updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes ingredient in listing", %{conn: conn, ingredient: ingredient} do
      {:ok, index_live, _html} = live(conn, ~p"/ingredients")

      assert index_live |> element("#ingredients-#{ingredient.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#ingredients-#{ingredient.id}")
    end
  end

  describe "Show" do
    setup [:create_ingredient]

    test "displays ingredient", %{conn: conn, ingredient: ingredient} do
      {:ok, _show_live, html} = live(conn, ~p"/ingredients/#{ingredient}")

      assert html =~ "Show Ingredient"
      assert html =~ ingredient.name
    end

    test "updates ingredient and returns to show", %{conn: conn, ingredient: ingredient} do
      {:ok, show_live, _html} = live(conn, ~p"/ingredients/#{ingredient}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/ingredients/#{ingredient}/edit?return_to=show")

      assert render(form_live) =~ "Edit Ingredient"

      assert form_live
             |> form("#ingredient-form", ingredient: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#ingredient-form", ingredient: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/ingredients/#{ingredient}")

      html = render(show_live)
      assert html =~ "Ingredient updated successfully"
      assert html =~ "some updated name"
    end
  end
end
