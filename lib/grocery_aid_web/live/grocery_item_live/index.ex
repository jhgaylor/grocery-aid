defmodule GroceryAidWeb.GroceryItemLive.Index do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog
  alias GroceryAid.Catalog.GroceryItem

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Grocery items
        <:subtitle>
          Things you buy that aren't recipe ingredients — cookies, cereal, paper towels.
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="grocery-item-form"
        phx-change="validate"
        phx-submit="save"
        class="grid grid-cols-1 sm:grid-cols-4 gap-2 items-end bg-base-200 rounded-box p-3"
      >
        <.input field={@form[:name]} type="text" label="Item" placeholder="Cereal" />
        <.input
          field={@form[:category]}
          type="select"
          label="Category"
          prompt="—"
          options={GroceryItem.categories()}
        />
        <.input
          field={@form[:preferred_store_id]}
          type="select"
          label="Preferred store"
          prompt="No preference"
          options={@store_options}
        />
        <.button variant="primary" phx-disable-with="Adding...">
          <.icon name="hero-plus" class="size-4" /> Add
        </.button>
      </.form>

      <.table id="grocery-items" rows={@streams.grocery_items}>
        <:col :let={{_id, gi}} label="Item">{gi.name}</:col>
        <:col :let={{_id, gi}} label="Category">{gi.category}</:col>
        <:col :let={{_id, gi}} label="Preferred store">
          <form phx-change="set_store" phx-value-id={gi.id}>
            <select name="value" class="select select-xs select-bordered">
              <option value="" selected={is_nil(gi.preferred_store_id)}>—</option>
              <option :for={s <- @stores} value={s.id} selected={gi.preferred_store_id == s.id}>
                {s.name}
              </option>
            </select>
          </form>
        </:col>
        <:action :let={{id, gi}}>
          <.link
            phx-click={JS.push("delete", value: %{id: gi.id}) |> hide("##{id}")}
            data-confirm="Remove this item?"
            class="text-error"
          >
            Delete
          </.link>
        </:action>
      </.table>

      <p :if={@empty} class="opacity-70 mt-2">
        No grocery items yet. Add cookies, cereal, or whatever staples you grab.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    items = Catalog.list_grocery_items()

    {:ok,
     socket
     |> assign(:page_title, "Grocery items")
     |> assign(:stores, Catalog.list_stores())
     |> assign(:store_options, Enum.map(Catalog.list_stores(), &{&1.name, &1.id}))
     |> assign(:empty, items == [])
     |> assign_form(Catalog.change_grocery_item(%GroceryItem{}))
     |> stream(:grocery_items, items)}
  end

  @impl true
  def handle_event("validate", %{"grocery_item" => params}, socket) do
    changeset = Catalog.change_grocery_item(%GroceryItem{}, params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"grocery_item" => params}, socket) do
    case Catalog.create_grocery_item(params) do
      {:ok, item} ->
        item = Catalog.get_grocery_item!(item.id)

        {:noreply,
         socket
         |> assign(:empty, false)
         |> assign_form(Catalog.change_grocery_item(%GroceryItem{}))
         |> stream_insert(:grocery_items, item, at: 0)}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("set_store", %{"id" => id, "value" => store_id}, socket) do
    item = Catalog.get_grocery_item!(id)
    {:ok, _} = Catalog.update_grocery_item(item, %{"preferred_store_id" => store_id})
    {:noreply, stream_insert(socket, :grocery_items, Catalog.get_grocery_item!(id))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    item = Catalog.get_grocery_item!(id)
    {:ok, _} = Catalog.delete_grocery_item(item)
    {:noreply, stream_delete(socket, :grocery_items, item)}
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))
end
