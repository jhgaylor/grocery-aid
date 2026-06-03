defmodule GroceryAid.Repo do
  use Ecto.Repo,
    otp_app: :grocery_aid,
    adapter: Ecto.Adapters.Postgres
end
