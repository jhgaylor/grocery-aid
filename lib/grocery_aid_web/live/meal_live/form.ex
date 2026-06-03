defmodule GroceryAidWeb.MealLive.Form do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Meals
  alias GroceryAid.Meals.Meal

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>
          The basics about a meal you like. Add the recipe's ingredients from its page.
        </:subtitle>
      </.header>

      <.form for={@form} id="meal-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:source_url]} type="text" label="Recipe / source URL" />
        <.input field={@form[:cuisine]} type="text" label="Cuisine" />
        <.input
          field={@form[:rating]}
          type="select"
          label="Rating"
          prompt="—"
          options={[{"★", 1}, {"★★", 2}, {"★★★", 3}, {"★★★★", 4}, {"★★★★★", 5}]}
        />
        <.input field={@form[:prep_minutes]} type="number" label="Prep minutes" />
        <.input field={@form[:last_made_on]} type="date" label="Last made on" />
        <.input
          name="tags"
          value={@tags_value}
          type="text"
          label="Tags"
          placeholder="thai, dinner, quick (comma separated)"
        />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Meal</.button>
          <.button navigate={return_path(@return_to, @meal)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    meal = id |> Meals.get_meal!() |> GroceryAid.Repo.preload(:tags)

    socket
    |> assign(:page_title, "Edit Meal")
    |> assign(:meal, meal)
    |> assign(:tags_value, meal.tags |> Enum.map(& &1.name) |> Enum.join(", "))
    |> assign(:form, to_form(Meals.change_meal(meal)))
  end

  defp apply_action(socket, :new, _params) do
    meal = %Meal{}

    socket
    |> assign(:page_title, "New Meal")
    |> assign(:meal, meal)
    |> assign(:tags_value, "")
    |> assign(:form, to_form(Meals.change_meal(meal)))
  end

  @impl true
  def handle_event("validate", %{"meal" => meal_params} = params, socket) do
    changeset = Meals.change_meal(socket.assigns.meal, meal_params)

    {:noreply,
     socket
     |> assign(:tags_value, Map.get(params, "tags", socket.assigns.tags_value))
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"meal" => meal_params} = params, socket) do
    save_meal(socket, socket.assigns.live_action, meal_params, Map.get(params, "tags", ""))
  end

  defp save_meal(socket, :edit, meal_params, tags) do
    case Meals.update_meal(socket.assigns.meal, meal_params) do
      {:ok, meal} ->
        Meals.set_meal_tags(meal, tags)

        {:noreply,
         socket
         |> put_flash(:info, "Meal updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, meal))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(:tags_value, tags) |> assign(:form, to_form(changeset))}
    end
  end

  defp save_meal(socket, :new, meal_params, tags) do
    case Meals.create_meal(meal_params) do
      {:ok, meal} ->
        Meals.set_meal_tags(meal, tags)

        {:noreply,
         socket
         |> put_flash(:info, "Meal created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, meal))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(:tags_value, tags) |> assign(:form, to_form(changeset))}
    end
  end

  defp return_path("index", _meal), do: ~p"/meals"
  defp return_path("show", meal), do: ~p"/meals/#{meal}"
end
