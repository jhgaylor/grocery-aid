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
  alias GroceryAid.Recipes.Lines

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
      enriched = Lines.enrich_all(lines, catalog)

      # Only trust the result if the model returned an entry per input line.
      if length(enriched) == length(raw_lines),
        do: {:ok, enriched},
        else: {:error, :count_mismatch}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:bad_payload, other}}
    end
  end

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
