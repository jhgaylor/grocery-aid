defmodule GroceryAidWeb.RecipeImportLive do
  use GroceryAidWeb, :live_view

  alias GroceryAid.{Catalog, Meals}
  alias GroceryAid.Recipes.Importer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Recipe")
     |> assign(:step, :url)
     |> assign(:url, "")
     |> assign(:loading, false)
     |> assign(:parsed, nil)
     |> assign(:existing, MapSet.new())}
  end

  @impl true
  def handle_event("fetch", %{"url" => url}, socket) do
    case Importer.import_from_url(url) do
      {:ok, parsed} ->
        existing =
          Catalog.list_ingredients()
          |> Enum.map(&String.downcase(&1.name))
          |> MapSet.new()

        {:noreply,
         socket
         |> assign(:step, :preview)
         |> assign(:url, url)
         |> assign(:parsed, parsed)
         |> assign(:existing, existing)}

      {:error, reason} ->
        {:noreply, socket |> assign(:url, url) |> put_flash(:error, reason)}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: :url, parsed: nil)}
  end

  def handle_event("create", %{"meal" => meal_params} = params, socket) do
    lines =
      params
      |> Map.get("lines", %{})
      |> Map.values()
      |> Enum.filter(&(&1["include"] == "true"))
      |> Enum.map(fn l ->
        %{
          name: String.trim(l["name"] || ""),
          quantity: blank_to_nil(l["quantity"]),
          unit: blank_to_nil(l["unit"])
        }
      end)
      |> Enum.reject(&(&1.name == ""))

    case Meals.create_imported_meal(meal_params, lines) do
      {:ok, meal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Imported \"#{meal.name}\" with #{length(lines)} ingredients")
         |> push_navigate(to: ~p"/meals/#{meal}")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Couldn't save — does a meal with that name already exist?")}
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s), do: s

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
          Works with most recipe sites (they embed schema.org Recipe data). If a site
          doesn't, add the meal manually instead.
        </p>
      </div>

      <div :if={@step == :preview}>
        <.form for={%{}} id="import-form" phx-submit="create">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <.input name="meal[name]" value={@parsed.name} type="text" label="Meal name" />
            <.input name="meal[cuisine]" value={@parsed.cuisine} type="text" label="Cuisine" />
          </div>
          <input type="hidden" name="meal[source_url]" value={@parsed.source_url} />
          <input
            :if={@parsed.prep_minutes}
            type="hidden"
            name="meal[prep_minutes]"
            value={@parsed.prep_minutes}
          />
          <.input
            name="meal[description]"
            value={@parsed.description}
            type="textarea"
            label="Description"
          />

          <div class="card bg-base-200 mt-4">
            <div class="card-body">
              <h2 class="card-title text-base">
                Ingredients
                <span class="badge badge-sm">{length(@parsed.ingredient_lines)} found</span>
              </h2>
              <p class="text-xs opacity-60">
                Untick lines that aren't real ingredients ("salt to taste"). Names you can edit;
                <span class="badge badge-xs badge-success badge-outline">new</span>
                ones get added to your catalog.
              </p>

              <div
                :for={{line, idx} <- Enum.with_index(@parsed.ingredient_lines)}
                class="flex items-center gap-2 py-1"
              >
                <input
                  type="checkbox"
                  name={"lines[#{idx}][include]"}
                  value="true"
                  checked
                  class="checkbox checkbox-sm"
                />
                <input type="hidden" name={"lines[#{idx}][quantity]"} value={fmt_qty(line.quantity)} />
                <input type="hidden" name={"lines[#{idx}][unit]"} value={line.unit} />
                <span class="text-sm opacity-70 w-24 shrink-0 text-right">
                  {fmt_qty(line.quantity)} {line.unit}
                </span>
                <input
                  type="text"
                  name={"lines[#{idx}][name]"}
                  value={line.name}
                  class="input input-sm input-bordered flex-1"
                />
                <span
                  :if={new?(line.name, @existing)}
                  class="badge badge-xs badge-success badge-outline"
                >
                  new
                </span>
              </div>
            </div>
          </div>

          <footer class="mt-4 flex gap-2">
            <.button variant="primary" phx-disable-with="Saving...">
              <.icon name="hero-check" class="size-4" /> Create meal
            </.button>
            <.button type="button" phx-click="back">Back</.button>
            <a
              :if={@parsed.source_url}
              href={@parsed.source_url}
              target="_blank"
              rel="noopener"
              class="btn btn-ghost"
            >
              View original
            </a>
          </footer>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp new?(name, existing), do: not MapSet.member?(existing, String.downcase(String.trim(name)))

  defp fmt_qty(nil), do: ""
  defp fmt_qty(%Decimal{} = d), do: d |> Decimal.normalize() |> Decimal.to_string(:normal)
  defp fmt_qty(other), do: to_string(other)
end
