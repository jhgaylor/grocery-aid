defmodule GroceryAidWeb.RecipeFlow do
  @moduledoc """
  Shared `create` handler for the recipe import and generate LiveViews: builds
  the meal + ingredient lines, applies tags, and navigates to the new meal.
  """
  import Phoenix.LiveView, only: [put_flash: 3, push_navigate: 2]
  use GroceryAidWeb, :verified_routes

  alias GroceryAid.Meals
  alias GroceryAidWeb.RecipeComponents

  def create(socket, meal_params, params) do
    lines = RecipeComponents.lines_from_params(params)

    case Meals.create_imported_meal(meal_params, lines) do
      {:ok, meal} ->
        Meals.set_meal_tags(meal, Map.get(params, "tags", ""))

        {:noreply,
         socket
         |> put_flash(:info, ~s(Saved "#{meal.name}" with #{length(lines)} ingredients))
         |> push_navigate(to: ~p"/meals/#{meal}")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Couldn't save — does a meal with that name already exist?")}
    end
  end
end
