defmodule GroceryAid.Recipes.Importer do
  @moduledoc """
  Best-effort recipe import from a URL. Most recipe sites embed a
  schema.org/Recipe object as JSON-LD in a `<script type="application/ld+json">`
  tag; we fetch the page, find that node, and pull out the name, ingredients,
  and a few other fields.

  Returns `{:ok, %Parsed{}}` or `{:error, reason}`. The caller previews/edits
  the result before anything is written — see `GroceryAidWeb.RecipeImportLive`.
  """

  require Logger

  defmodule Parsed do
    @moduledoc "A parsed recipe, pre-persistence."
    defstruct name: nil,
              description: nil,
              source_url: nil,
              cuisine: nil,
              prep_minutes: nil,
              servings: nil,
              image: nil,
              # list of %{raw:, quantity:, unit:, name:}
              ingredient_lines: []
  end

  @known_units ~w(
    teaspoon teaspoons tsp tablespoon tablespoons tbsp tbsps cup cups
    pint pints quart quarts gallon gallons ounce ounces oz pound pounds lb lbs
    gram grams g kilogram kilograms kg milliliter milliliters ml liter liters l
    clove cloves can cans jar jars package packages pkg pinch pinches dash dashes
    slice slices stick sticks bunch bunches head heads sprig sprigs stalk stalks
    handful piece pieces each
  )

  @doc "Fetch + parse a recipe URL."
  def import_from_url(url) when is_binary(url) do
    url = String.trim(url)

    with :ok <- validate_url(url),
         {:ok, body} <- fetch(url),
         {:ok, recipe} <- extract_recipe_jsonld(body) do
      {:ok, to_parsed(recipe, url)}
    end
  end

  defp validate_url(url) do
    case URI.parse(url) do
      %URI{scheme: s, host: h} when s in ["http", "https"] and is_binary(h) -> :ok
      _ -> {:error, "That doesn't look like a valid http(s) URL."}
    end
  end

  defp fetch(url) do
    case Req.get(url,
           headers: [
             # Some recipe sites 403 the default Req UA; pretend to be a browser.
             {"user-agent",
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"},
             {"accept", "text/html,application/xhtml+xml"}
           ],
           max_redirects: 5,
           receive_timeout: 15_000,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, "The site returned HTTP #{status}."}

      {:error, %{__exception__: true} = e} ->
        Logger.warning("recipe fetch failed: #{Exception.message(e)}")
        {:error, "Couldn't reach that URL."}

      {:error, _} ->
        {:error, "Couldn't reach that URL."}
    end
  end

  @doc false
  # Public so it can be unit-tested without a network round-trip.
  def extract_recipe_jsonld(html) when is_binary(html) do
    with {:ok, doc} <- Floki.parse_document(html) do
      doc
      |> Floki.find(~s(script[type="application/ld+json"]))
      # Floki.text/1 strips <script> bodies by default, so read the script
      # element's raw children (the JSON string) directly.
      |> Enum.map(fn {_tag, _attrs, children} -> children |> List.wrap() |> Enum.join("") end)
      |> Enum.flat_map(&decode_jsonld/1)
      |> Enum.flat_map(&flatten_graph/1)
      |> Enum.find(&recipe?/1)
      |> case do
        nil -> {:error, "No recipe data found on that page (no schema.org Recipe)."}
        recipe -> {:ok, recipe}
      end
    end
  end

  defp decode_jsonld(text) do
    case Jason.decode(text) do
      {:ok, list} when is_list(list) -> list
      {:ok, map} when is_map(map) -> [map]
      _ -> []
    end
  end

  # JSON-LD often nests everything under "@graph"; unwrap it.
  defp flatten_graph(%{"@graph" => graph}) when is_list(graph), do: graph
  defp flatten_graph(map) when is_map(map), do: [map]
  defp flatten_graph(_), do: []

  defp recipe?(%{"@type" => type}), do: type_is_recipe?(type)
  defp recipe?(_), do: false

  defp type_is_recipe?("Recipe"), do: true
  defp type_is_recipe?(types) when is_list(types), do: Enum.any?(types, &type_is_recipe?/1)
  defp type_is_recipe?(t) when is_binary(t), do: String.downcase(t) == "recipe"
  defp type_is_recipe?(_), do: false

  defp to_parsed(recipe, url) do
    %Parsed{
      name: string_field(recipe["name"]),
      description: recipe["description"] |> string_field() |> truncate(500),
      source_url: string_field(recipe["url"]) || url,
      cuisine: recipe["recipeCuisine"] |> first_string(),
      prep_minutes:
        parse_duration(recipe["totalTime"] || recipe["cookTime"] || recipe["prepTime"]),
      servings: parse_yield(recipe["recipeYield"] || recipe["yield"]),
      image: image_url(recipe["image"]),
      ingredient_lines:
        recipe
        |> Map.get("recipeIngredient", [])
        |> List.wrap()
        |> Enum.map(&to_string/1)
        |> Enum.map(&decode_entities/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&parse_ingredient_line/1)
    }
  end

  defp string_field(s) when is_binary(s),
    do: s |> decode_entities() |> String.trim() |> emptyish()

  defp string_field(_), do: nil

  # JSON-LD strings sometimes carry HTML entities ("&amp;", "&#39;"). Decode
  # the common named ones plus numeric (&#39; / &#x27;) references.
  defp decode_entities(s) do
    s
    |> String.replace(~r/&#(\d+);/, fn m ->
      [_, n] = Regex.run(~r/&#(\d+);/, m)
      <<String.to_integer(n)::utf8>>
    end)
    |> String.replace(~r/&#x([0-9a-fA-F]+);/, fn m ->
      [_, n] = Regex.run(~r/&#x([0-9a-fA-F]+);/, m)
      <<String.to_integer(n, 16)::utf8>>
    end)
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&nbsp;", " ")
  end

  defp emptyish(""), do: nil
  defp emptyish(s), do: s

  defp first_string(s) when is_binary(s), do: string_field(s)
  defp first_string([h | _]), do: first_string(h)
  defp first_string(_), do: nil

  defp truncate(nil, _), do: nil
  defp truncate(s, max) when byte_size(s) <= max, do: s
  defp truncate(s, max), do: String.slice(s, 0, max)

  defp image_url(s) when is_binary(s), do: s
  defp image_url(%{"url" => u}) when is_binary(u), do: u
  defp image_url([h | _]), do: image_url(h)
  defp image_url(_), do: nil

  @doc """
  Parses an ISO-8601 duration ("PT1H30M", "PT35M") into whole minutes.
  """
  def parse_duration(nil), do: nil

  def parse_duration(s) when is_binary(s) do
    case Regex.run(~r/^PT(?:(\d+)H)?(?:(\d+)M)?/, s) do
      [_, h, m] -> to_int(h) * 60 + to_int(m)
      [_, h] -> to_int(h) * 60
      _ -> nil
    end
    |> case do
      0 -> nil
      n -> n
    end
  end

  def parse_duration(_), do: nil

  defp to_int(""), do: 0
  defp to_int(nil), do: 0
  defp to_int(s), do: String.to_integer(s)

  @doc """
  Extracts a serving count from a schema.org `recipeYield`, which may be a
  number, `"8"`, `"8 servings"`, `"Serves 8"`, or a list. Returns the first
  positive integer found, or nil.
  """
  def parse_yield(n) when is_integer(n) and n > 0, do: n
  def parse_yield([h | _]), do: parse_yield(h)

  def parse_yield(s) when is_binary(s) do
    case Regex.run(~r/\d+/, s) do
      [n] -> String.to_integer(n)
      _ -> nil
    end
  end

  def parse_yield(_), do: nil

  @frac_map %{"½" => "0.5", "¼" => "0.25", "¾" => "0.75", "⅓" => "0.333", "⅔" => "0.667"}

  @doc """
  Splits a recipe ingredient string into `%{raw, quantity, unit, name}`.
  Heuristic, not perfect: leading number (incl. fractions) → quantity, an
  optional known unit, the rest → name. Always keeps the original `raw`.
  """
  def parse_ingredient_line(raw) when is_binary(raw) do
    line = raw |> String.trim() |> normalize_fractions()
    {quantity, rest} = take_quantity(line)
    {unit, rest} = take_unit(rest)
    name = rest |> strip_prep_notes() |> String.trim() |> emptyish()

    %{raw: raw, quantity: quantity, unit: unit, name: name || raw}
  end

  defp normalize_fractions(s) do
    Enum.reduce(@frac_map, s, fn {sym, dec}, acc ->
      String.replace(acc, sym, " " <> dec)
    end)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # "1 1/2", "1/2", "2", "2.5" at the start → Decimal.
  defp take_quantity(line) do
    case Regex.run(~r/^(\d+\s+\d+\/\d+|\d+\/\d+|\d+(?:\.\d+)?)\s*(.*)$/, line) do
      [_, qty_str, rest] -> {decimalize(qty_str), rest}
      _ -> {nil, line}
    end
  end

  defp decimalize(str) do
    str = String.trim(str)

    cond do
      # mixed number "1 1/2"
      String.match?(str, ~r/^\d+\s+\d+\/\d+$/) ->
        [whole, frac] = String.split(str, " ", parts: 2)
        Decimal.add(Decimal.new(whole), frac_to_decimal(frac))

      # plain fraction "1/2"
      String.match?(str, ~r/^\d+\/\d+$/) ->
        frac_to_decimal(str)

      true ->
        case Decimal.parse(str) do
          {d, _} -> d
          :error -> nil
        end
    end
  end

  defp frac_to_decimal(frac) do
    [num, den] = String.split(frac, "/")
    Decimal.div(Decimal.new(num), Decimal.new(den)) |> Decimal.round(3)
  end

  defp take_unit(rest) do
    case String.split(rest, " ", parts: 2) do
      [first, tail] ->
        normalized = first |> String.downcase() |> String.trim_trailing(".")
        if normalized in @known_units, do: {normalized, tail}, else: {nil, rest}

      _ ->
        {nil, rest}
    end
  end

  # Drop trailing prep notes after a comma ("basil, chopped" -> "basil").
  defp strip_prep_notes(name) do
    name |> String.split(",", parts: 2) |> hd()
  end
end
