defmodule GroceryAidWeb.StoreLive.Index do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Stores
        <:actions>
          <.button variant="primary" navigate={~p"/stores/new"}>
            <.icon name="hero-plus" /> New Store
          </.button>
        </:actions>
      </.header>

      <.table
        id="stores"
        rows={@streams.stores}
        row_click={fn {_id, store} -> JS.navigate(~p"/stores/#{store}") end}
      >
        <:col :let={{_id, store}} label="Name">{store.name}</:col>
        <:col :let={{_id, store}} label="Location">{store.location}</:col>
        <:col :let={{_id, store}} label="Url">{store.url}</:col>
        <:col :let={{_id, store}} label="Notes">{store.notes}</:col>
        <:action :let={{_id, store}}>
          <div class="sr-only">
            <.link navigate={~p"/stores/#{store}"}>Show</.link>
          </div>
          <.link navigate={~p"/stores/#{store}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, store}}>
          <.link
            phx-click={JS.push("delete", value: %{id: store.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Stores")
     |> stream(:stores, list_stores())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    store = Catalog.get_store!(id)
    {:ok, _} = Catalog.delete_store(store)

    {:noreply, stream_delete(socket, :stores, store)}
  end

  defp list_stores() do
    Catalog.list_stores()
  end
end
