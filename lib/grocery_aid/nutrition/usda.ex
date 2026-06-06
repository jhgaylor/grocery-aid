defmodule GroceryAid.Nutrition.USDA do
  @moduledoc """
  Thin client for USDA FoodData Central — authoritative per-100g nutrition.

  `candidates/1` searches by ingredient name and returns the top foods that
  have an energy (kcal/100g) value, each with its FDC id + description.
  Prefers Foundation / SR Legacy data (generic whole foods, reliably per-100g)
  and falls back to Branded products. A caller (see `GroceryAid.Nutrition`)
  picks the best candidate — USDA search ranking alone is noisy
  (e.g. "basmati rice" can rank "Rice crackers" first).

  Needs a free API key (`FDC_API_KEY`); `DEMO_KEY` works at low rate limits.
  """
  require Logger

  @base "https://api.nal.usda.gov/fdc/v1/foods/search"
  @energy_kcal_number "208"

  @doc "Returns `{:ok, [%{fdc_id, description, calories_per_100g}]}` or `{:error, reason}`."
  def candidates(name) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      {:error, :empty}
    else
      case search(name, ["Foundation", "SR Legacy"]) do
        {:ok, []} -> search(name, ["Branded"])
        other -> other
      end
    end
  end

  defp search(query, data_types) do
    params = [
      query: query,
      dataType: Enum.join(data_types, ","),
      pageSize: 15,
      api_key: api_key()
    ]

    case Req.get(@base, params: params, receive_timeout: 15_000, retry: false) do
      {:ok, %Req.Response{status: 200, body: %{"foods" => foods}}} when is_list(foods) ->
        {:ok, foods |> Enum.map(&to_candidate/1) |> Enum.reject(&is_nil/1)}

      {:ok, %Req.Response{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("USDA FDC HTTP #{status}")
        {:error, {:http_error, status}}

      {:error, e} ->
        Logger.warning("USDA FDC transport error: #{inspect(e)}")
        {:error, :transport_error}
    end
  end

  defp to_candidate(food) do
    case energy_kcal(food) do
      nil -> nil
      kcal -> %{fdc_id: food["fdcId"], description: food["description"], calories_per_100g: kcal}
    end
  end

  defp energy_kcal(%{"foodNutrients" => nutrients}) when is_list(nutrients) do
    Enum.find_value(nutrients, fn n ->
      number = to_string(n["nutrientNumber"] || n["number"])
      unit = String.upcase(to_string(n["unitName"] || ""))
      value = n["value"]

      if number == @energy_kcal_number and unit == "KCAL" and is_number(value) and value > 0 do
        value * 1.0
      end
    end)
  end

  defp energy_kcal(_), do: nil

  defp api_key, do: Application.get_env(:grocery_aid, :fdc_api_key, "DEMO_KEY")
end
