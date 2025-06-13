defmodule LoadTester do
  use Application
  require Logger

  @default_payload_path "payload.json"

  def start(_type, _args) do
    # Load environment variables from .env
    Dotenv.load()

    target_url = System.get_env("TARGET_URL")
    # Allow both the variable names used by the other language implementations (NUM_THREADS, REQUESTS_PER_THREAD)
    # and the original Elixir names (CONCURRENT_USERS, REQUESTS_PER_USER) for compatibility
    requests_per_user_str =
      System.get_env("REQUESTS_PER_USER") ||
        System.get_env("REQUESTS_PER_THREAD") || "10"

    concurrent_users_str =
      System.get_env("CONCURRENT_USERS") ||
        System.get_env("NUM_THREADS") || "5"
    payload_path = System.get_env("PAYLOAD_PATH", @default_payload_path)
    auth_token = System.get_env("AUTH_TOKEN", "")

    unless target_url do
      Logger.error("TARGET_URL must be set in .env file or environment variables.")
      System.halt(1)
    end

    requests_per_user = String.to_integer(requests_per_user_str)
    concurrent_users = String.to_integer(concurrent_users_str)

    payload_content =
      case File.read(payload_path) do
        {:ok, body} ->
          case Jason.decode(body) do
            {:ok, json_payload} -> json_payload
            {:error, reason} ->
              Logger.error("Failed to parse JSON from #{payload_path}: #{inspect(reason)}")
              System.halt(1)
          end
        {:error, reason} ->
          Logger.error("Failed to read payload file #{payload_path}: #{inspect(reason)}")
          System.halt(1)
      end

    total_requests_planned = concurrent_users * requests_per_user

    Logger.info("🚀 Starting load test (Elixir with HTTPoison & Dotenv)...")
    Logger.info("Threads: #{concurrent_users}, Requests/User: #{requests_per_user}, Total: #{total_requests_planned}")
    Logger.info("Target URL: #{target_url}")
    if auth_token != "" do
      Logger.info("Auth Token: Provided (Bearer)")
    else
      Logger.info("Auth Token: Not set")
    end
    Logger.info(String.duplicate("-", 70))

    start_time = :erlang.system_time(:millisecond)

    pids =
      for i <- 1..concurrent_users do
        {:ok, pid} = LoadTester.Worker.start_link(target_url, requests_per_user, payload_content, auth_token, i)
        pid
      end

    results =
      pids
      |> Enum.map(&GenServer.call(&1, :get_results, :infinity))
      |> Enum.reduce({0, 0, 0, :infinity, 0}, fn {s, f, d, min_d, max_d},
                                                {acc_s, acc_f, acc_d, acc_min, acc_max} ->
        new_min =
          case {acc_min, min_d} do
            {:infinity, _} -> min_d
            {_, 0} -> acc_min
            {a, b} -> min(a, b)
          end

        {acc_s + s, acc_f + f, acc_d + d, new_min, max(acc_max, max_d)}
      end)

    end_time = :erlang.system_time(:millisecond)
    total_duration_ms = end_time - start_time
    total_duration_s = total_duration_ms / 1000

    {total_successes, total_failures, total_duration_workers_ms, min_duration_ms, max_duration_ms} = results
    total_requests = total_successes + total_failures
    average_duration_workers_ms = if total_requests > 0, do: total_duration_workers_ms / total_requests, else: 0

    Logger.info(String.duplicate("-", 70))
    Logger.info("✅ Test completed in #{:erlang.float_to_binary(total_duration_ms / 1000, decimals: 2)} s")
    Logger.info("Total requests: #{total_requests}")
    Logger.info("  -> Successes ✅: #{total_successes}")
    Logger.info("  -> Failures ❌: #{total_failures}")

    if total_duration_s > 0 do
      rps = total_requests / total_duration_s
      Logger.info("Performance: ~#{:erlang.float_to_binary(rps, decimals: 2)} requests/second (RPS)")
    else
      Logger.info("Performance: RPS could not be calculated (duration zero)")
    end
    Logger.info("Average request duration: #{:erlang.float_to_binary(average_duration_workers_ms, decimals: 2)} ms")
    if min_duration_ms != :infinity do
      Logger.info(
        "Response times (ms): min #{:erlang.float_to_binary(min_duration_ms / 1.0, decimals: 2)} | avg #{:erlang.float_to_binary(average_duration_workers_ms, decimals: 2)} | max #{:erlang.float_to_binary(max_duration_ms / 1.0, decimals: 2)}"
      )
    end

    # Tell Mix that the application has finished so the executable can exit
    Application.stop(:load_tester)
    System.halt(0)
  end

  # main/1 is required for escript
  def main(_args) do
    start(:normal, [])
  end
end
