defmodule GroceryAidWeb.RecipeGenerateLive do
  use GroceryAidWeb, :live_view

  import GroceryAidWeb.RecipeComponents

  alias GroceryAid.{Catalog, Recipes.Generator}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Describe a Meal")
     |> assign(:step, :prompt)
     |> assign(:description, "")
     |> assign(:available, Generator.available?())
     |> assign(:meal, nil)
     |> assign(:lines, [])
     |> assign(:tags_value, "")}
  end

  @impl true
  def handle_event("generate", %{"description" => description}, socket) do
    case Generator.generate(description, Catalog.list_ingredients()) do
      {:ok, gen} ->
        meal = Map.take(gen, [:name, :cuisine, :servings, :description])

        {:noreply,
         socket
         |> assign(step: :preview, description: description, meal: meal)
         |> assign(lines: gen.lines, tags_value: gen.tags)}

      {:error, :empty} ->
        {:noreply, put_flash(socket, :error, "Describe the meal first.")}

      {:error, :no_api_key} ->
        {:noreply, put_flash(socket, :error, "AI generation isn't configured on this instance.")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:description, description)
         |> put_flash(
           :error,
           "Couldn't generate that — try rephrasing, or add the meal manually."
         )}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: :prompt, meal: nil, lines: [])}
  end

  def handle_event("create", %{"meal" => meal_params} = params, socket) do
    GroceryAidWeb.RecipeFlow.create(socket, meal_params, params)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Describe a meal
        <:subtitle>
          No recipe needed — just say what's in it and we'll turn it into a meal with ingredients.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/meals"}><.icon name="hero-arrow-left" /></.button>
        </:actions>
      </.header>

      <div :if={@step == :prompt}>
        <p :if={not @available} class="alert alert-warning text-sm mb-3">
          AI generation isn't configured on this instance.
          <.link navigate={~p"/meals/new"} class="link">Add a meal manually</.link>
          or <.link navigate={~p"/meals/import"} class="link">import from a URL</.link>.
        </p>

        <.form for={%{}} id="describe-form" phx-submit="generate">
          <.input
            name="description"
            value={@description}
            type="textarea"
            label="What's the meal?"
            placeholder="spaghetti with meat sauce — angel hair, a jar of red sauce, some ground beef and an onion"
          />
          <footer class="mt-2">
            <.button variant="primary" phx-disable-with="Thinking..." disabled={not @available}>
              <.icon name="hero-sparkles" class="size-4" /> Generate
            </.button>
          </footer>
        </.form>

        <p class="text-sm opacity-60 mt-4">
          Tip: a name plus the main ingredients is plenty. You'll review and edit everything,
          including quantities and matches, before it's saved.
        </p>
      </div>

      <.recipe_preview
        :if={@step == :preview}
        meal={@meal}
        lines={@lines}
        tags_value={@tags_value}
        enhanced={true}
        submit_label="Create meal"
      />
    </Layouts.app>
    """
  end
end
