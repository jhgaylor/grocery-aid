defmodule GroceryAidWeb.MealLiveTest do
  use GroceryAidWeb.ConnCase

  import Phoenix.LiveViewTest
  import GroceryAid.MealsFixtures

  @create_attrs %{
    name: "some name",
    description: "some description",
    source_url: "some source_url",
    cuisine: "some cuisine",
    rating: 42,
    prep_minutes: 42,
    last_made_on: "2026-06-02",
    notes: "some notes"
  }
  @update_attrs %{
    name: "some updated name",
    description: "some updated description",
    source_url: "some updated source_url",
    cuisine: "some updated cuisine",
    rating: 43,
    prep_minutes: 43,
    last_made_on: "2026-06-03",
    notes: "some updated notes"
  }
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
  defp create_meal(_) do
    meal = meal_fixture()

    %{meal: meal}
  end

  describe "Index" do
    setup [:create_meal]

    test "lists all meals", %{conn: conn, meal: meal} do
      {:ok, _index_live, html} = live(conn, ~p"/meals")

      assert html =~ "Listing Meals"
      assert html =~ meal.name
    end

    test "saves new meal", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/meals")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Meal")
               |> render_click()
               |> follow_redirect(conn, ~p"/meals/new")

      assert render(form_live) =~ "New Meal"

      assert form_live
             |> form("#meal-form", meal: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#meal-form", meal: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/meals")

      html = render(index_live)
      assert html =~ "Meal created successfully"
      assert html =~ "some name"
    end

    test "updates meal in listing", %{conn: conn, meal: meal} do
      {:ok, index_live, _html} = live(conn, ~p"/meals")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#meals-#{meal.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/meals/#{meal}/edit")

      assert render(form_live) =~ "Edit Meal"

      assert form_live
             |> form("#meal-form", meal: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#meal-form", meal: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/meals")

      html = render(index_live)
      assert html =~ "Meal updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes meal in listing", %{conn: conn, meal: meal} do
      {:ok, index_live, _html} = live(conn, ~p"/meals")

      assert index_live |> element("#meals-#{meal.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#meals-#{meal.id}")
    end
  end

  describe "Show" do
    setup [:create_meal]

    test "displays meal", %{conn: conn, meal: meal} do
      {:ok, _show_live, html} = live(conn, ~p"/meals/#{meal}")

      assert html =~ "Show Meal"
      assert html =~ meal.name
    end

    test "updates meal and returns to show", %{conn: conn, meal: meal} do
      {:ok, show_live, _html} = live(conn, ~p"/meals/#{meal}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/meals/#{meal}/edit?return_to=show")

      assert render(form_live) =~ "Edit Meal"

      assert form_live
             |> form("#meal-form", meal: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#meal-form", meal: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/meals/#{meal}")

      html = render(show_live)
      assert html =~ "Meal updated successfully"
      assert html =~ "some updated name"
    end
  end
end
