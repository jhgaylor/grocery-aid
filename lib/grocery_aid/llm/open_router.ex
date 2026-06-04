defmodule GroceryAid.LLM.OpenRouter do
  @moduledoc """
  Stateless HTTP client for OpenRouter's chat completions API, for one-shot
  tasks like recipe-ingredient normalization. Mirrors the adapter in `guild`,
  but uses Req (grocery-aid's HTTP dep).

  Returns `{:ok, %{text:, model:, prompt_tokens:, completion_tokens:, cost_usd:}}`
  or `{:error, reason}`. Callers treat any error as "fall back to the
  deterministic path" — the LLM is an enhancement, never a hard dependency.
  """

  require Logger

  @default_url "https://openrouter.ai/api/v1/chat/completions"
  @default_model "openai/gpt-4o-mini"
  @timeout_ms 20_000

  @doc "Returns true if an API key is configured."
  def configured?, do: present?(api_key())

  @doc """
  Single-turn completion. `opts`:
    * `:model` — override the configured model
    * `:json` — when true, ask the model for a JSON object response
    * `:max_tokens` (default 1500), `:temperature` (default 0.1)
  """
  def complete(prompt, opts \\ []) do
    if configured?() do
      do_complete(prompt, opts)
    else
      {:error, :no_api_key}
    end
  end

  defp do_complete(prompt, opts) do
    model = opts[:model] || configured_model()

    body =
      %{
        model: model,
        messages: [%{role: "user", content: prompt}],
        max_tokens: opts[:max_tokens] || 1500,
        temperature: opts[:temperature] || 0.1,
        usage: %{include: true}
      }
      |> maybe_json_mode(opts[:json])

    headers = [
      {"authorization", "Bearer #{api_key()}"},
      {"content-type", "application/json"},
      {"http-referer", "https://grocery-aid.inevitable.fyi"},
      {"x-title", "Grocery Aid"}
    ]

    case Req.post(api_url(),
           json: body,
           headers: headers,
           receive_timeout: @timeout_ms,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: resp}} when status in 200..299 ->
        parse_response(resp, model)

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("OpenRouter HTTP #{status}")
        {:error, {:http_error, status}}

      {:error, e} ->
        Logger.warning("OpenRouter transport error: #{inspect(e)}")
        {:error, :transport_error}
    end
  end

  defp maybe_json_mode(body, true), do: Map.put(body, :response_format, %{type: "json_object"})
  defp maybe_json_mode(body, _), do: body

  # Req auto-decodes JSON responses into maps.
  defp parse_response(%{"choices" => [%{"message" => %{"content" => text}} | _]} = decoded, model) do
    usage = Map.get(decoded, "usage", %{})

    {:ok,
     %{
       text: text,
       model: Map.get(decoded, "model") || model,
       prompt_tokens: usage["prompt_tokens"],
       completion_tokens: usage["completion_tokens"],
       cost_usd: usage["cost"] || usage["total_cost"]
     }}
  end

  defp parse_response(other, _model) do
    Logger.warning("OpenRouter: unexpected response shape: #{inspect(other)}")
    {:error, :unexpected_shape}
  end

  defp api_key, do: Application.get_env(:grocery_aid, :openrouter_api_key)
  defp api_url, do: Application.get_env(:grocery_aid, :openrouter_api_url, @default_url)

  defp configured_model,
    do: Application.get_env(:grocery_aid, :openrouter_model, @default_model)

  defp present?(v), do: is_binary(v) and v != ""
end
