defmodule GroceryAid.Recipes.Normalizer do
  @moduledoc """
  Optional LLM pass over parsed recipe ingredient lines. Given the raw lines
  and the user's existing catalog, it returns cleaned `{quantity, unit, name}`,
  a suggested category, and a confident match to an existing catalog ingredient
  (so we don't create "chicken breast" twice).

  Deterministic-first: if OpenRouter isn't configured or the call fails / comes
  back malformed, returns `{:error, reason}` and the caller keeps the heuristic
  parse. The LLM never blocks an import.
  """

  require Logger

  alias GroceryAid.Catalog.Ingredient
  alias GroceryAid.LLM.OpenRouter

  @doc "Whether the LLM enhancement is available (API key configured)."
  def available?, do: OpenRouter.configured?()

  @doc """
  Normalizes `raw_lines` (strings) against `catalog` (list of `%Ingredient{}`).
  Returns `{:ok, [enriched]}` where each enriched line is
  `%{raw, quantity, unit, name, category, matched_id, matched_name}`, aligned
  one-per-input-line, or `{:error, reason}`.
  """
  def normalize(raw_lines, catalog) when is_list(raw_lines) do
    cond do
      raw_lines == [] -> {:ok, []}
      not available?() -> {:error, :no_api_key}
      true -> do_normalize(raw_lines, catalog)
    end
  end

  defp do_normalize(raw_lines, catalog) do
    with {:ok, %{text: text}} <- OpenRouter.complete(prompt(raw_lines, catalog), json: true),
         {:ok, %{"lines" => lines}} when is_list(lines) <- Jason.decode(text) do
      by_id = Map.new(catalog, &{&1.id, &1})
      enriched = lines |> Enum.map(&enrich(&1, by_id)) |> Enum.reject(&is_nil/1)

      # Only trust the result if the model returned an entry per input line.
      if length(enriched) == length(raw_lines),
        do: {:ok, enriched},
        else: {:error, :count_mismatch}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:bad_payload, other}}
    end
  end

  defp enrich(%{"raw" => raw} = line, by_id) when is_binary(raw) do
    matched = match_ingredient(line["match_id"], by_id)

    %{
      raw: raw,
      quantity: to_decimal(line["quantity"]),
      unit: blank_to_nil(line["unit"]),
      name: (blank_to_nil(line["name"]) || raw) |> String.trim(),
      category: valid_category(line["category"]),
      matched_id: matched && matched.id,
      matched_name: matched && matched.name
    }
  end

  defp enrich(_, _), do: nil

  defp match_ingredient(id, by_id) when is_integer(id), do: Map.get(by_id, id)

  defp match_ingredient(id, by_id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> Map.get(by_id, n)
      _ -> nil
    end
  end

  defp match_ingredient(_, _), do: nil

  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n) |> Decimal.round(3)

  defp to_decimal(s) when is_binary(s) do
    case Decimal.parse(String.trim(s)) do
      {d, _} -> d
      :error -> nil
    end
  end

  defp to_decimal(_), do: nil

  defp blank_to_nil(s) when is_binary(s),
    do: if(String.trim(s) == "", do: nil, else: String.trim(s))

  defp blank_to_nil(_), do: nil

  defp valid_category(c) when is_binary(c) do
    c = String.downcase(String.trim(c))
    if c in Ingredient.categories(), do: c, else: nil
  end

  defp valid_category(_), do: nil

  defp prompt(raw_lines, catalog) do
    catalog_block =
      case catalog do
        [] ->
          "(the catalog is currently empty)"

        items ->
          items
          |> Enum.map(fn i -> "#{i.id}: #{i.name}#{i.category && " [#{i.category}]"}" end)
          |> Enum.join("\n")
      end

    lines_block =
      raw_lines
      |> Enum.with_index(1)
      |> Enum.map(fn {l, i} -> "#{i}. #{l}" end)
      |> Enum.join("\n")

    """
    You normalize recipe ingredient lines for a grocery app.

    EXISTING CATALOG INGREDIENTS (id: name [category]):
    #{catalog_block}

    RECIPE INGREDIENT LINES (numbered):
    #{lines_block}

    Return ONLY a JSON object of the form:
    {"lines": [{"raw": "...", "quantity": <number or null>, "unit": "<short unit or null>", "name": "<canonical name>", "category": "<category or null>", "match_id": <existing id or null>}]}

    Rules:
    - Output EXACTLY one entry per input line, in the same order. Do not skip any.
    - "name": the canonical, singular, lowercase shopping name — strip prep words and brands.
      e.g. "boneless skinless chicken breasts, diced" -> "chicken breast";
      "2 (14 oz) cans chickpeas, drained" -> "chickpeas".
    - "quantity"/"unit": numeric amount and a short unit ("cup","tbsp","lb","clove","can"); null if none ("salt to taste" -> both null).
    - "category": one of #{Enum.join(Ingredient.categories(), ", ")}; or null if unsure.
    - "match_id": the id of an EXISTING catalog ingredient that is the SAME ingredient, only when confident; otherwise null.
    - Output valid JSON only, no prose.
    """
  end
end
