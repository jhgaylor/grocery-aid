defmodule GroceryAid.Recipes.Lines do
  @moduledoc """
  Shared validation/enrichment for LLM-produced ingredient lines. Both the
  recipe Normalizer (import) and Generator (describe-a-meal) get back the same
  JSON line shape and turn it into the enriched map the preview UI consumes:

      %{raw, quantity, unit, name, category, matched_id, matched_name}
  """

  alias GroceryAid.Catalog.Ingredient

  @doc """
  Enriches a list of raw JSON line maps against `catalog` (`[%Ingredient{}]`).
  Drops any malformed entries.
  """
  def enrich_all(json_lines, catalog) when is_list(json_lines) do
    by_id = Map.new(catalog, &{&1.id, &1})
    json_lines |> Enum.map(&enrich(&1, by_id)) |> Enum.reject(&is_nil/1)
  end

  @doc "Enriches one JSON line map given an `id => %Ingredient{}` lookup."
  def enrich(%{"name" => _} = line, by_id), do: do_enrich(line, by_id)
  def enrich(%{"raw" => _} = line, by_id), do: do_enrich(line, by_id)
  def enrich(_, _), do: nil

  defp do_enrich(line, by_id) do
    matched = match_ingredient(line["match_id"], by_id)
    name = blank_to_nil(line["name"]) || blank_to_nil(line["raw"])

    if name do
      %{
        raw: line["raw"] || name,
        quantity: to_decimal(line["quantity"]),
        unit: blank_to_nil(line["unit"]),
        name: String.trim(name),
        category: valid_category(line["category"]),
        matched_id: matched && matched.id,
        matched_name: matched && matched.name
      }
    end
  end

  defp match_ingredient(id, by_id) when is_integer(id), do: Map.get(by_id, id)

  defp match_ingredient(id, by_id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> Map.get(by_id, n)
      _ -> nil
    end
  end

  defp match_ingredient(_, _), do: nil

  def to_decimal(n) when is_integer(n), do: Decimal.new(n)
  def to_decimal(n) when is_float(n), do: Decimal.from_float(n) |> Decimal.round(3)

  def to_decimal(s) when is_binary(s) do
    case Decimal.parse(String.trim(s)) do
      {d, _} -> d
      :error -> nil
    end
  end

  def to_decimal(_), do: nil

  def blank_to_nil(s) when is_binary(s) do
    if String.trim(s) == "", do: nil, else: String.trim(s)
  end

  def blank_to_nil(_), do: nil

  def valid_category(c) when is_binary(c) do
    c = String.downcase(String.trim(c))
    if c in Ingredient.categories(), do: c, else: nil
  end

  def valid_category(_), do: nil
end
