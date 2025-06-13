defmodule LoadTester.Worker do
  use GenServer
  require Logger

  # Client API (GenServer callbacks)
  def start_link(url, num_requests, payload, auth_token, worker_id) do
    GenServer.start_link(__MODULE__, {url, num_requests, payload, auth_token, worker_id})
  end

  # Server callbacks (GenServer)
  @impl true
  def init({url, num_requests, payload, auth_token, worker_id}) do
    # Send a message to itself to start sending requests.
    # This allows init to return quickly and ensures the GenServer is ready.
    send(self(), :execute_requests)
    {:ok,
     %{
       url: url,
       num_requests: num_requests,
       payload: payload,
       auth_token: auth_token,
       worker_id: worker_id,
       successes: 0,
       failures: 0,
       total_duration_ms: 0,
       min_duration_ms: :infinity,
       max_duration_ms: 0
     }}
  end

  @impl true
  def handle_info(:execute_requests, state) do
    # Logger.debug("Worker #{state.worker_id}: Starting to send #{state.num_requests} requests to #{state.url}")
    updated_state = send_all_requests(state)
    # Logger.debug("Worker #{state.worker_id}: Finished sending requests.")
    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:get_results, _from, state) do
    {:reply,
     {
       state.successes,
       state.failures,
       state.total_duration_ms,
       if(state.min_duration_ms == :infinity, do: 0, else: state.min_duration_ms),
       state.max_duration_ms
     }, state}
  end

  # Helper functions
  defp send_all_requests(state) do
    Enum.reduce(1..state.num_requests, state, fn _request_num, acc_state ->
      send_single_request(acc_state)
    end)
  end

  defp send_single_request(state) do
    start_time = :erlang.system_time(:millisecond)
    base_headers = [{"Content-Type", "application/json"}]
    headers = if state.auth_token != "" do
      [{"Authorization", "Bearer " <> state.auth_token} | base_headers]
    else
      base_headers
    end
    body = Jason.encode!(state.payload) # Assuming the payload is an Elixir map

    case HTTPoison.post(state.url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: _response_body}} ->
        end_time = :erlang.system_time(:millisecond)
        duration_ms = end_time - start_time
        if status_code >= 200 && status_code < 300 do
          current_req_num = state.successes + state.failures + 1
          Logger.info(
            "Worker #{state.worker_id} | Request #{current_req_num}/#{state.num_requests} | Status: #{status_code}"
          )

          update_duration_metrics(state, duration_ms, :success)
        else
          Logger.warning("Worker #{state.worker_id}: Request failed (Status: #{status_code}) in #{duration_ms}ms")
          update_duration_metrics(state, duration_ms, :failure)
        end
      {:error, %HTTPoison.Error{reason: reason}} ->
        end_time = :erlang.system_time(:millisecond)
        duration_ms = end_time - start_time # Even on error we still record the duration
        Logger.error("Worker #{state.worker_id}: Request error: #{inspect(reason)}")
        update_duration_metrics(state, duration_ms, :failure)
    end
  end

  # Update success/failure counters and min/max/total durations
  defp update_duration_metrics(state, duration_ms, outcome) do
    new_min =
      case state.min_duration_ms do
        :infinity -> duration_ms
        existing -> min(existing, duration_ms)
      end

    new_max = max(state.max_duration_ms, duration_ms)

    state
    |> Map.update!(:total_duration_ms, &(&1 + duration_ms))
    |> Map.put(:min_duration_ms, new_min)
    |> Map.put(:max_duration_ms, new_max)
    |> increment_counter(outcome)
  end

  defp increment_counter(state, :success),
    do: %{state | successes: state.successes + 1}

  defp increment_counter(state, :failure),
    do: %{state | failures: state.failures + 1}
end
