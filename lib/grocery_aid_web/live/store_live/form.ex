defmodule GroceryAidWeb.StoreLive.Form do
  use GroceryAidWeb, :live_view

  alias GroceryAid.Catalog
  alias GroceryAid.Catalog.Store

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage store records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="store-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:location]} type="text" label="Location" />
        <.input field={@form[:url]} type="text" label="Url" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Store</.button>
          <.button navigate={return_path(@return_to, @store)}>Cancel</.button>
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
    store = Catalog.get_store!(id)

    socket
    |> assign(:page_title, "Edit Store")
    |> assign(:store, store)
    |> assign(:form, to_form(Catalog.change_store(store)))
  end

  defp apply_action(socket, :new, _params) do
    store = %Store{}

    socket
    |> assign(:page_title, "New Store")
    |> assign(:store, store)
    |> assign(:form, to_form(Catalog.change_store(store)))
  end

  @impl true
  def handle_event("validate", %{"store" => store_params}, socket) do
    changeset = Catalog.change_store(socket.assigns.store, store_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"store" => store_params}, socket) do
    save_store(socket, socket.assigns.live_action, store_params)
  end

  defp save_store(socket, :edit, store_params) do
    case Catalog.update_store(socket.assigns.store, store_params) do
      {:ok, store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, store))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_store(socket, :new, store_params) do
    case Catalog.create_store(store_params) do
      {:ok, store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, store))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _store), do: ~p"/stores"
  defp return_path("show", store), do: ~p"/stores/#{store}"
end
