defmodule ArweaveSdkEx.Utils.ExHttp do
  @moduledoc """
    the encapsulation of http
  """
  require Logger

  @retries 5

  @doc """
    +----------------------+
    | json_rpc_constructer |
    +----------------------+
  """
  @spec json_rpc(String.t(), integer()) :: map()
  def json_rpc(method, id) when is_integer(id) do
    %{method: method, jsonrpc: "2.0", id: id}
  end

  @spec json_rpc(String.t(), map()) :: map()
  def json_rpc(method, params) do
    %{method: method, params: params, jsonrpc: "2.0", id: 1}
  end

  @doc """
    +-------------+
    | get request |
    +-------------+
  """
  @spec get(any) :: {:error, String.t()} | {:ok, any}
  def get(url) do
    do_get(url, @retries)
  end

  @spec get(String.t(), atom()) :: {:error, String.t()} | {:ok, any}
  def get(url, :once) do
    url
    |> HTTPoison.get([])
    |> handle_response()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  def get(url, :plain) do
    case get(url, :redirect) do
      {:ok, %{body: body}} ->
        {:ok, body}
      {:error, msg} ->
        {:error, inspect(msg)}
    end
  end

  def get(url, :redirect) do
    :get
    |> HTTPoison.request(url, "", [], [hackney: [{:follow_redirect, true}]])
    |> handle_response_spec()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, _} ->
        Process.sleep(500)
        do_get(url, @retries - 1)
    end
  end

  defp do_get(_url, retries) when retries == 0 do
    {:error, "retires #{@retries} times and not success"}
  end

  defp do_get(url, retries) do
    url
    |> HTTPoison.get([])
    |> handle_response()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, _} ->
        Process.sleep(500)
        do_get(url, retries - 1)
    end
  end

  @doc """
    +--------------+
    | post request |
    +--------------+
  """
  @spec post(String.t(), map()) :: {:error, String.t()} | {:ok, any}
  def post(url, body) do
    do_post(url, body, @retries)
  end

  @spec post(String.t(), map(), atom()) :: {:error, String.t()} | {:ok, any}
  def post(url, body, type) do
    do_post(url, body, @retries, type)
  end

  def post(url, body, type, :without_encode) do
    do_post(url, body, @retries, type, :without_encode)
  end


  defp do_post(_url, _body, retires) when retires == 0 do
    {:error, "retires #{@retries} times and not success"}
  end

  defp do_post(url, body, retries) do
    url
    |> HTTPoison.post(
      Poison.encode!(body),
      [{"Content-Type", "application/json"}]
    )
    |> handle_response()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, _} ->
        Process.sleep(500)
        do_post(url, body, retries - 1)
    end
  end

  defp do_post(_url, _body, retires, _) when retires == 0 do
    {:error, "retires #{@retries} times and not success"}
  end

  defp do_post(url, body, retries, :urlencoded) do
    url
    |> HTTPoison.post(
      body,
      [{"Content-Type", "application/x-www-form-urlencoded"}]
    )
    |> handle_response()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, _} ->
        Process.sleep(500)
        do_post(url, body, retries - 1)
    end
  end

  defp do_post(url, body, retries, :resp_plain) do
    url
    |> HTTPoison.post(
      Poison.encode!(body),
      [
        {"Content-Type", "application/json"},
        {"Accept", "text/plain"},
      ])
    |> handle_response_spec()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, _} ->
        Process.sleep(500)
        do_post(url, body, retries - 1, :resp_plain)
    end
  end


  defp do_post(url, body, retries, :resp_plain, :without_encode) do
    url
    |> HTTPoison.post(
      body,
      [
        {"Content-Type", "application/json"},
        {"Accept", "text/plain"},
      ])
    |> handle_response_spec()
    |> case do
      {:ok, body} ->
        {:ok, body}

      {:error, _} ->
        Process.sleep(500)
        do_post(url, body, retries - 1, :resp_plain, :without_encode)
    end
  end

  # normal
  defp handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}})
       when status_code in 200..299 do
    case Poison.decode(body) do
      {:ok, json_body} ->
        {:ok, json_body}

      {:error, payload} ->
        Logger.error("Reason: #{inspect(payload)}")
        {:error, :network_error}
    end
  end

  # 404 or sth else
  defp handle_response({:ok, %HTTPoison.Response{status_code: status_code, body: _}}) do
    Logger.error("Reason: #{status_code} ")
    {:error, :network_error}
  end

  defp handle_response(error) do
    Logger.error("Reason: other_error")
    error
  end

  defp handle_response_spec({:ok, %{status_code: 200}} = payload) do
    payload
  end

  # 404 or sth else
  defp handle_response_spec(others), do: handle_response(others)


end
