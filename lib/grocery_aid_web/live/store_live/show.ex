defmodule GroceryAidWeb.StoreLive.Show do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@store.name}
        <:subtitle>{@store.location}</:subtitle>
        <:actions>
          <.button navigate={~p"/stores"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/stores/#{@store}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit store
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item :if={@store.url} title="Website">
          <a href={@store.url} target="_blank" rel="noopener" class="link link-primary">
            {@store.url}
          </a>
        </:item>
        <:item :if={@store.notes} title="Notes">{@store.notes}</:item>
      </.list>

      <div class="card bg-base-200 mt-6">
        <div class="card-body">
          <h2 class="card-title">Carries</h2>
          <ul :if={@store.store_items != []} class="divide-y divide-base-300">
            <li :for={si <- @store.store_items} class="py-2 flex items-center justify-between">
              <.link navigate={~p"/ingredients/#{si.ingredient}"} class="link link-hover">
                {si.ingredient.name}
                <span :if={si.aisle} class="text-xs opacity-60">· aisle {si.aisle}</span>
              </.link>
              <span :if={si.price} class="text-sm opacity-70">${si.price}</span>
            </li>
          </ul>
          <p :if={@store.store_items == []} class="opacity-70">
            No ingredients linked yet. Link them from an <.link
              navigate={~p"/ingredients"}
              class="link"
            >ingredient's page</.link>.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    store = Catalog.get_store_with_items!(id)

    {:ok,
     socket
     |> assign(:page_title, store.name)
     |> assign(:store, store)}
  end
end
