defmodule GroceryAidWeb.PageController do
  use GroceryAidWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
