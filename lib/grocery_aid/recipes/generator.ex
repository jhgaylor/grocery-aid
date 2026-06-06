defmodule GroceryAid.Recipes.Generator do
  @moduledoc """
  Builds a structured meal from a freeform description via the LLM — e.g.
  "spaghetti with meat sauce: angel hair, a jar of red sauce, ground beef and
  an onion" becomes a named meal with quantified ingredients, a serving count,
  and suggested tags, each ingredient matched to the existing catalog.

  Requires OpenRouter to be configured (unlike import, there's no deterministic
  fallback — the whole point is the LLM). Returns
  `{:ok, %{name, cuisine, servings, description, tags, lines}}` or
  `{:error, reason}`. `lines` use the shared enriched shape (see
  `GroceryAid.Recipes.Lines`).
  """

  alias GroceryAid.Catalog.Ingredient
  alias GroceryAid.LLM.OpenRouter
  alias GroceryAid.Recipes.Lines

  @doc "Whether generation is available (LLM configured)."
  def available?, do: OpenRouter.configured?()

  def generate(description, catalog) when is_binary(description) do
    cond do
      String.trim(description) == "" -> {:error, :empty}
      not available?() -> {:error, :no_api_key}
      true -> do_generate(description, catalog)
    end
  end

  defp do_generate(description, catalog) do
    with {:ok, %{text: text}} <- OpenRouter.complete(prompt(description, catalog), json: true),
         {:ok, %{"ingredients" => ings} = data} when is_list(ings) <- Jason.decode(text) do
      {:ok,
       %{
         name: str(data["name"]) || "New meal",
         cuisine: str(data["cuisine"]),
         servings: pos_int(data["servings"]),
         description: str(data["description"]),
         tags: tags(data["tags"]),
         lines: Lines.enrich_all(ings, catalog)
       }}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, {:bad_payload, other}}
    end
  end

  defp str(s) when is_binary(s), do: Lines.blank_to_nil(s)
  defp str(_), do: nil

  defp pos_int(n) when is_integer(n) and n > 0, do: n

  defp pos_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} when n > 0 -> n
      _ -> nil
    end
  end

  defp pos_int(_), do: nil

  defp tags(list) when is_list(list) do
    list
    |> Enum.map(&to_string/1)
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.join(", ")
  end

  defp tags(_), do: ""

  defp prompt(description, catalog) do
    catalog_block =
      case catalog do
        [] ->
          "(the catalog is currently empty)"

        items ->
          items
          |> Enum.map(fn i -> "#{i.id}: #{i.name}#{i.category && " [#{i.category}]"}" end)
          |> Enum.join("\n")
      end

    """
    You turn a freeform meal description into a structured recipe for a grocery app.

    DESCRIPTION:
    #{description}

    EXISTING CATALOG INGREDIENTS (id: name [category]):
    #{catalog_block}

    Return ONLY a JSON object:
    {"name": "...", "cuisine": "..." or null, "servings": <int>, "description": "<one short sentence>" or null, "tags": ["dinner","italian"], "ingredients": [{"name": "<canonical lowercase>", "quantity": <number or null>, "unit": "<short unit or null>", "category": "<category or null>", "match_id": <existing id or null>}]}

    Rules:
    - Stay close to what the user described; only add an ingredient if it's clearly implied. Don't invent a full from-scratch recipe.
    - "name": a clear meal title (e.g. "Spaghetti with Meat Sauce").
    - "servings": a sensible batch size (default 4 if unclear).
    - ingredient "name": canonical, singular, lowercase shopping name (e.g. "ground beef", "yellow onion", "angel hair pasta", "marinara sauce").
    - "quantity"/"unit": realistic amounts for the serving count; use null when not applicable. Prefer shopping units a store uses ("jar", "can", "lb", "box").
    - "category": one of #{Enum.join(Ingredient.categories(), ", ")}; or null.
    - "match_id": id of an EXISTING catalog ingredient that is the SAME ingredient, only when confident; else null.
    - "tags": 1-4 short lowercase tags (meal slot / cuisine / diet).
    - Output valid JSON only, no prose.
    """
  end
end
