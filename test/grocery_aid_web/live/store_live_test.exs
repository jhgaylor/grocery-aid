defmodule GroceryAidWeb.StoreLiveTest do
  use GroceryAidWeb.ConnCase

  import Phoenix.LiveViewTest
  import GroceryAid.CatalogFixtures

  @create_attrs %{
    name: "some name",
    location: "some location",
    url: "some url",
    notes: "some notes"
  }
  @update_attrs %{
    name: "some updated name",
    location: "some updated location",
    url: "some updated url",
    notes: "some updated notes"
  }
  @invalid_attrs %{name: nil, location: nil, url: nil, notes: nil}
  defp create_store(_) do
    store = store_fixture()

    %{store: store}
  end

  describe "Index" do
    setup [:create_store]

    test "lists all stores", %{conn: conn, store: store} do
      {:ok, _index_live, html} = live(conn, ~p"/stores")

      assert html =~ "Listing Stores"
      assert html =~ store.name
    end

    test "saves new store", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/stores")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Store")
               |> render_click()
               |> follow_redirect(conn, ~p"/stores/new")

      assert render(form_live) =~ "New Store"

      assert form_live
             |> form("#store-form", store: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#store-form", store: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/stores")

      html = render(index_live)
      assert html =~ "Store created successfully"
      assert html =~ "some name"
    end

    test "updates store in listing", %{conn: conn, store: store} do
      {:ok, index_live, _html} = live(conn, ~p"/stores")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#stores-#{store.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/stores/#{store}/edit")

      assert render(form_live) =~ "Edit Store"

      assert form_live
             |> form("#store-form", store: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#store-form", store: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/stores")

      html = render(index_live)
      assert html =~ "Store updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes store in listing", %{conn: conn, store: store} do
      {:ok, index_live, _html} = live(conn, ~p"/stores")

      assert index_live |> element("#stores-#{store.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#stores-#{store.id}")
    end
  end

  describe "Show" do
    setup [:create_store]

    test "displays store", %{conn: conn, store: store} do
      {:ok, _show_live, html} = live(conn, ~p"/stores/#{store}")

      assert html =~ "Show Store"
      assert html =~ store.name
    end

    test "updates store and returns to show", %{conn: conn, store: store} do
      {:ok, show_live, _html} = live(conn, ~p"/stores/#{store}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/stores/#{store}/edit?return_to=show")

      assert render(form_live) =~ "Edit Store"

      assert form_live
             |> form("#store-form", store: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#store-form", store: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/stores/#{store}")

      html = render(show_live)
      assert html =~ "Store updated successfully"
      assert html =~ "some updated name"
    end
  end
end
