defmodule GroceryAidWeb.RecipeImportLive do
  use GroceryAidWeb, :live_view

  import GroceryAidWeb.RecipeComponents

  alias GroceryAid.Catalog
  alias GroceryAid.Recipes.{Importer, Normalizer}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Recipe")
     |> assign(:step, :url)
     |> assign(:url, "")
     |> assign(:meal, nil)
     |> assign(:lines, [])
     |> assign(:enhanced, false)}
  end

  @impl true
  def handle_event("fetch", %{"url" => url}, socket) do
    case Importer.import_from_url(url) do
      {:ok, parsed} ->
        {lines, enhanced} = enhance(parsed)

        meal = %{
          name: parsed.name,
          cuisine: parsed.cuisine,
          servings: parsed.servings,
          description: parsed.description,
          source_url: parsed.source_url,
          prep_minutes: parsed.prep_minutes
        }

        {:noreply,
         socket
         |> assign(step: :preview, url: url, meal: meal, lines: lines, enhanced: enhanced)}

      {:error, reason} ->
        {:noreply, socket |> assign(:url, url) |> put_flash(:error, reason)}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: :url, meal: nil, lines: [])}
  end

  def handle_event("create", %{"meal" => meal_params} = params, socket) do
    GroceryAidWeb.RecipeFlow.create(socket, meal_params, params)
  end

  # Run the optional LLM normalization; fall back to the deterministic parse.
  defp enhance(parsed) do
    raw_lines = Enum.map(parsed.ingredient_lines, & &1.raw)

    case Normalizer.normalize(raw_lines, Catalog.list_ingredients()) do
      {:ok, enriched} -> {enriched, true}
      {:error, _} -> {Enum.map(parsed.ingredient_lines, &deterministic_line/1), false}
    end
  end

  defp deterministic_line(line) do
    %{
      raw: line.raw,
      quantity: line.quantity,
      unit: line.unit,
      name: line.name,
      category: nil,
      matched_id: nil,
      matched_name: nil
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Import a recipe
        <:subtitle>
          Paste a recipe URL — we'll pull the name and ingredients so you don't have to type them.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/meals"}><.icon name="hero-arrow-left" /></.button>
        </:actions>
      </.header>

      <div :if={@step == :url}>
        <.form for={%{}} id="url-form" phx-submit="fetch">
          <.input
            name="url"
            value={@url}
            type="url"
            label="Recipe URL"
            placeholder="https://www.example.com/recipes/coconut-chicken-curry"
          />
          <footer class="mt-2">
            <.button variant="primary" phx-disable-with="Fetching...">
              <.icon name="hero-arrow-down-tray" class="size-4" /> Fetch recipe
            </.button>
          </footer>
        </.form>
        <p class="text-sm opacity-60 mt-4">
          Works with most recipe sites (they embed schema.org Recipe data). No URL? Try
          <.link navigate={~p"/meals/generate"} class="link">describing the meal</.link>
          instead.
        </p>
      </div>

      <.recipe_preview
        :if={@step == :preview}
        meal={@meal}
        lines={@lines}
        enhanced={@enhanced}
        submit_label="Create meal"
      />
    </Layouts.app>
    """
  end
end
