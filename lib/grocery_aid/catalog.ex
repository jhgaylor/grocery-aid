defmodule GroceryAid.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias GroceryAid.Repo

  alias GroceryAid.Catalog.Ingredient

  @doc """
  Returns the list of ingredients.

  ## Examples

      iex> list_ingredients()
      [%Ingredient{}, ...]

  """
  def list_ingredients do
    Ingredient |> order_by(asc: :name) |> Repo.all()
  end

  @doc """
  Gets a single ingredient.

  Raises `Ecto.NoResultsError` if the Ingredient does not exist.

  ## Examples

      iex> get_ingredient!(123)
      %Ingredient{}

      iex> get_ingredient!(456)
      ** (Ecto.NoResultsError)

  """
  def count_ingredients, do: Repo.aggregate(Ingredient, :count)

  def get_ingredient!(id), do: Repo.get!(Ingredient, id)

  @doc """
  Gets an ingredient with its store availability (and each store) preloaded.
  """
  def get_ingredient_with_stores!(id) do
    Ingredient
    |> Repo.get!(id)
    |> Repo.preload(store_items: [:store])
  end

  @doc """
  Creates a ingredient.

  ## Examples

      iex> create_ingredient(%{field: value})
      {:ok, %Ingredient{}}

      iex> create_ingredient(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ingredient(attrs) do
    %Ingredient{}
    |> Ingredient.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ingredient.

  ## Examples

      iex> update_ingredient(ingredient, %{field: new_value})
      {:ok, %Ingredient{}}

      iex> update_ingredient(ingredient, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ingredient(%Ingredient{} = ingredient, attrs) do
    ingredient
    |> Ingredient.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ingredient.

  ## Examples

      iex> delete_ingredient(ingredient)
      {:ok, %Ingredient{}}

      iex> delete_ingredient(ingredient)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ingredient(%Ingredient{} = ingredient) do
    Repo.delete(ingredient)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ingredient changes.

  ## Examples

      iex> change_ingredient(ingredient)
      %Ecto.Changeset{data: %Ingredient{}}

  """
  def change_ingredient(%Ingredient{} = ingredient, attrs \\ %{}) do
    Ingredient.changeset(ingredient, attrs)
  end

  alias GroceryAid.Catalog.Store

  @doc """
  Returns the list of stores.

  ## Examples

      iex> list_stores()
      [%Store{}, ...]

  """
  def list_stores do
    Store |> order_by(asc: :name) |> Repo.all()
  end

  @doc """
  Gets a single store.

  Raises `Ecto.NoResultsError` if the Store does not exist.

  ## Examples

      iex> get_store!(123)
      %Store{}

      iex> get_store!(456)
      ** (Ecto.NoResultsError)

  """
  def count_stores, do: Repo.aggregate(Store, :count)

  def get_store!(id), do: Repo.get!(Store, id)

  @doc """
  Gets a store with the items it carries (and each ingredient) preloaded.
  """
  def get_store_with_items!(id) do
    Store
    |> Repo.get!(id)
    |> Repo.preload(store_items: [:ingredient])
  end

  @doc """
  Creates a store.

  ## Examples

      iex> create_store(%{field: value})
      {:ok, %Store{}}

      iex> create_store(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_store(attrs) do
    %Store{}
    |> Store.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a store.

  ## Examples

      iex> update_store(store, %{field: new_value})
      {:ok, %Store{}}

      iex> update_store(store, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_store(%Store{} = store, attrs) do
    store
    |> Store.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a store.

  ## Examples

      iex> delete_store(store)
      {:ok, %Store{}}

      iex> delete_store(store)
      {:error, %Ecto.Changeset{}}

  """
  def delete_store(%Store{} = store) do
    Repo.delete(store)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking store changes.

  ## Examples

      iex> change_store(store)
      %Ecto.Changeset{data: %Store{}}

  """
  def change_store(%Store{} = store, attrs \\ %{}) do
    Store.changeset(store, attrs)
  end

  alias GroceryAid.Catalog.StoreItem

  @doc """
  Lists every store_item (ingredient availability at a store), with the
  ingredient and store preloaded. Ordered by store then ingredient name.
  """
  def list_store_items do
    StoreItem
    |> join(:inner, [si], s in assoc(si, :store))
    |> join(:inner, [si, _s], i in assoc(si, :ingredient))
    |> order_by([_si, s, i], asc: s.name, asc: i.name)
    |> preload([:store, :ingredient])
    |> Repo.all()
  end

  def get_store_item!(id), do: Repo.get!(StoreItem, id) |> Repo.preload([:store, :ingredient])

  def create_store_item(attrs) do
    %StoreItem{}
    |> StoreItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_store_item(%StoreItem{} = store_item, attrs) do
    store_item
    |> StoreItem.changeset(attrs)
    |> Repo.update()
  end

  def delete_store_item(%StoreItem{} = store_item), do: Repo.delete(store_item)

  def change_store_item(%StoreItem{} = store_item, attrs \\ %{}) do
    StoreItem.changeset(store_item, attrs)
  end
end
