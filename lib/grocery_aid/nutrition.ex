defmodule GroceryAid.Nutrition do
  @moduledoc """
  Nutrition orchestration: authoritative per-100g energy from USDA FDC, with
  the LLM doing the two judgement calls USDA can't:

    * `lookup/1` — pick the candidate that actually matches the plain ingredient
      (USDA search ranking is noisy), returning its kcal/100g + provenance.
    * `grams_for/1` — convert recipe lines ("1 jar", "2 cups") to grams so the
      per-100g energy can be applied.

  Both degrade gracefully: no LLM → take USDA's first candidate / deterministic
  mass conversions only.
  """
  require Logger

  alias GroceryAid.LLM.OpenRouter
  alias GroceryAid.Nutrition.USDA

  # Deterministic mass/weight units → grams (no LLM needed).
  @gram_factors %{
    "g" => 1.0,
    "gram" => 1.0,
    "grams" => 1.0,
    "kg" => 1000.0,
    "kilogram" => 1000.0,
    "oz" => 28.3495,
    "ounce" => 28.3495,
    "ounces" => 28.3495,
    "lb" => 453.592,
    "lbs" => 453.592,
    "pound" => 453.592,
    "pounds" => 453.592
  }

  @doc "Best per-100g nutrition match for an ingredient name, or `{:error, reason}`."
  def lookup(name) do
    term = search_term(name)

    case USDA.candidates(term) do
      {:ok, [_ | _] = candidates} ->
        {:ok, choose(name, candidates)}

      # Normalized term found nothing — retry with the original name.
      {:ok, []} when term != name ->
        case USDA.candidates(name) do
          {:ok, [_ | _] = candidates} -> {:ok, choose(name, candidates)}
          {:ok, []} -> {:error, :no_match}
          {:error, reason} -> {:error, reason}
        end

      {:ok, []} ->
        {:error, :no_match}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Ask the LLM for a clean generic USDA query (e.g. "basmati rice" -> "white
  # rice"), so the candidate set actually contains the right food. Falls back
  # to the raw name.
  defp search_term(name) do
    if OpenRouter.configured?() do
      prompt = """
      Give the best concise USDA FoodData Central search query for the ingredient "#{name}".
      Strip brands and varieties; use the common raw/generic food name (e.g. "basmati rice"
      -> "white rice", "boneless chicken thighs" -> "chicken thigh").
      Return ONLY JSON {"q": "..."}.
      """

      with {:ok, %{text: text}} <- OpenRouter.complete(prompt, json: true),
           {:ok, %{"q" => q}} when is_binary(q) <- Jason.decode(text),
           q = String.trim(q),
           true <- q != "" do
        q
      else
        _ -> name
      end
    else
      name
    end
  end

  defp choose(_name, [only]), do: only

  defp choose(name, candidates) do
    # Drop brand/restaurant entries ("TACO BELL, Nachos", "DENNY'S, ...") which
    # USDA mixes into SR Legacy and which derail matching — unless that's all
    # there is.
    pool =
      case Enum.reject(candidates, &branded?(&1.description)) do
        [] -> candidates
        cleaned -> cleaned
      end

    cond do
      match?([_], pool) -> hd(pool)
      OpenRouter.configured?() -> llm_choose(name, pool) || prefer_raw(pool)
      true -> prefer_raw(pool)
    end
  end

  # ALL-CAPS tokens (brands) or restaurant markers signal a non-generic entry.
  defp branded?(description) do
    String.match?(description, ~r/\b[A-Z]{3,}\b/) or
      String.downcase(description) =~ ~r/\brestaurant\b|\bfast food\b/
  end

  # Fallback: prefer a "raw" generic entry, else the first.
  defp prefer_raw(candidates) do
    Enum.find(
      candidates,
      hd(candidates),
      &String.contains?(String.downcase(&1.description), "raw")
    )
  end

  defp llm_choose(name, candidates) do
    options =
      candidates
      |> Enum.with_index()
      |> Enum.map(fn {c, i} ->
        "#{i}. #{c.description} (#{round(c.calories_per_100g)} kcal/100g)"
      end)
      |> Enum.join("\n")

    prompt = """
    Pick the option that best represents the plain ingredient "#{name}" as bought raw/generic
    for home cooking, for a calorie estimate.
    #{options}

    Guidance:
    - Prefer the simplest raw/whole-food form (e.g. "basmati rice" -> plain white rice, raw;
      "bell pepper" -> raw bell pepper; "sirloin" -> beef sirloin, not veal).
    - Avoid prepared dishes, snacks, and anything unlike the ingredient (e.g. don't pick
      "croutons" for "seasoned salt" — pick table salt; don't pick nachos for a pepper).
    - The calories should be plausible for that ingredient.

    Return ONLY JSON {"index": <integer>} with the best option's number, or {"index": null}
    if none are a reasonable match.
    """

    with {:ok, %{text: text}} <- OpenRouter.complete(prompt, json: true),
         {:ok, %{"index" => i}} when is_integer(i) <- Jason.decode(text),
         candidate when not is_nil(candidate) <- Enum.at(candidates, i) do
      candidate
    else
      _ -> nil
    end
  end

  @doc """
  Estimates grams for each line (`[%{name, quantity, unit}]`), aligned by order.
  Mass units convert deterministically; everything else uses the LLM (nil when
  it can't be determined).
  """
  def grams_for(lines) when is_list(lines) do
    deterministic = Enum.map(lines, &deterministic_grams/1)

    # Only call the LLM for lines we couldn't convert directly.
    if Enum.any?(deterministic, &is_nil/1) and OpenRouter.configured?() do
      llm = llm_grams(lines)

      Enum.zip_with(deterministic, llm || List.duplicate(nil, length(lines)), fn d, l ->
        d || l
      end)
    else
      deterministic
    end
  end

  defp deterministic_grams(%{quantity: %Decimal{} = q, unit: unit}) when is_binary(unit) do
    case Map.get(@gram_factors, String.downcase(String.trim(unit))) do
      nil -> nil
      factor -> Decimal.to_float(q) * factor
    end
  end

  defp deterministic_grams(_), do: nil

  defp llm_grams(lines) do
    listing =
      lines
      |> Enum.with_index(1)
      |> Enum.map(fn {l, i} ->
        q = if l.quantity, do: Decimal.to_string(l.quantity), else: ""
        "#{i}. #{String.trim("#{q} #{l.unit}")} #{l.name}"
      end)
      |> Enum.join("\n")

    prompt = """
    Estimate the total edible weight in grams for each ingredient line below.
    #{listing}

    Use standard conversions (1 lb=454 g, 1 oz=28 g, 1 cup water≈240 g) and typical
    package/portion sizes (a jar of pasta sauce ≈ 680 g, a can ≈ 400 g, a clove of
    garlic ≈ 3 g, one medium onion ≈ 110 g). Return ONLY JSON
    {"grams": [<number per line, in order>]} — one number per line, no nulls.
    """

    with {:ok, %{text: text}} <- OpenRouter.complete(prompt, json: true),
         {:ok, %{"grams" => grams}} when is_list(grams) and length(grams) == length(lines) <-
           Jason.decode(text) do
      Enum.map(grams, &to_number/1)
    else
      _ -> nil
    end
  end

  defp to_number(n) when is_number(n), do: n * 1.0
  defp to_number(_), do: nil
end
