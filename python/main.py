import os
import threading
import time
import json
import logging
import statistics
from dotenv import load_dotenv
import requests  # type: ignore

# --- Configuration ---
load_dotenv()  # Load .env file from current directory or parent directories

NUM_THREADS = int(os.getenv("NUM_THREADS", "20"))
REQUESTS_PER_THREAD = int(os.getenv("REQUESTS_PER_THREAD", "50"))
TARGET_URL = os.getenv("TARGET_URL", "http://localhost:3000/api/foo")
AUTH_TOKEN = os.getenv("AUTH_TOKEN", "")
PAYLOAD_FILE = "payload.json"  # Assumed to be in the same directory as main.py

# --- Logging Setup ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# --- Global Metrics ---
# Using lists to store durations from all threads, then process them
# For min/max/avg, it's simpler to collect all and then compute
# For counts and total duration, atomicity is needed if Python's GIL wasn't simplifying things for CPython.
# However, for simplicity and typical load testing scenarios where exact atomicity for sums might be
# slightly off but statistically okay over many requests, we'll use basic appends and sums.
# For truly atomic counters in Python threading, a Lock would be used around updates.
# We'll use locks for thread-safety on shared lists/counters.

all_response_times_ns = []
success_count = 0
failure_count = 0
total_duration_ns_overall = 0  # Sum of durations of all successful requests

metrics_lock = threading.Lock()


# --- Worker Function ---
def worker(thread_id: int, payload_data: bytes):
    global success_count, failure_count, total_duration_ns_overall

    session = requests.Session()
    headers = {"Content-Type": "application/json"}
    if AUTH_TOKEN:
        headers["Authorization"] = f"Bearer {AUTH_TOKEN}"

    for i in range(REQUESTS_PER_THREAD):
        req_num = i + 1
        start_time = time.perf_counter_ns()

        try:
            response = session.post(
                TARGET_URL, data=payload_data, headers=headers, timeout=30
            )  # 30s timeout
            response_time_ns = time.perf_counter_ns() - start_time

            with metrics_lock:
                all_response_times_ns.append(response_time_ns)
                total_duration_ns_overall += response_time_ns

                if response.status_code == 200 or response.status_code == 201:
                    success_count += 1
                else:
                    failure_count += 1

            logger.info(
                f"Thread {thread_id:>2} | Request {req_num:>3}/{REQUESTS_PER_THREAD} | Status: {response.status_code}"
            )
            response.close()  # Ensure resources are released

        except requests.exceptions.RequestException as e:
            response_time_ns = (
                time.perf_counter_ns() - start_time
            )  # Record time even for errors
            with metrics_lock:
                all_response_times_ns.append(
                    response_time_ns
                )  # Optionally record error times
                failure_count += 1
            logger.error(
                f"Thread {thread_id:>2} | Request {req_num:>3}/{REQUESTS_PER_THREAD} | Error: {e}"
            )
        except Exception as e:  # Catch any other unexpected errors
            with metrics_lock:
                failure_count += 1
            logger.error(
                f"Thread {thread_id:>2} | Request {req_num:>3}/{REQUESTS_PER_THREAD} | Unexpected Error: {e}"
            )


# --- Main Execution ---
def main():
    if (
        not TARGET_URL
        or TARGET_URL == "http://localhost:3000/api/foo"
        and os.getenv("TARGET_URL") is None
    ):
        logger.warning(f"TARGET_URL is not explicitly set. Using default: {TARGET_URL}")
    if PAYLOAD_FILE == "payload.json" and not os.path.exists(PAYLOAD_FILE):
        logger.warning(
            f"{PAYLOAD_FILE} not found in the current directory. POST requests will have an empty body if not created."
        )
        payload_data = b""
    else:
        try:
            with open(PAYLOAD_FILE, "rb") as f:
                payload_data = f.read()
        except FileNotFoundError:
            logger.error(
                f"Error: {PAYLOAD_FILE} not found. Please create it in the 'python/' directory."
            )
            return
        except Exception as e:
            logger.error(f"Error reading {PAYLOAD_FILE}: {e}")
            return

    total_requests_to_make = NUM_THREADS * REQUESTS_PER_THREAD

    logger.info("🚀 Starting load test (Python)...")
    logger.info(
        f"Threads: {NUM_THREADS}, Requests/Thread: {REQUESTS_PER_THREAD}, Total: {total_requests_to_make}"
    )
    logger.info(f"Target URL: {TARGET_URL}")
    if not AUTH_TOKEN:
        logger.info("Auth Token: Not set")
    else:
        logger.info("Auth Token: Set (hidden)")
    logger.info(
        "----------------------------------------------------------------------"
    )

    overall_start_time = time.perf_counter()

    threads = []
    for i in range(NUM_THREADS):
        thread = threading.Thread(target=worker, args=(i + 1, payload_data))
        threads.append(thread)
        thread.start()

    for thread in threads:
        thread.join()

    overall_duration_s = time.perf_counter() - overall_start_time
    overall_duration_ms = overall_duration_s * 1000

    # --- Metrics Calculation ---
    # success_count, failure_count are already updated by threads

    actual_total_requests = (
        success_count + failure_count
    )  # Could be less than total_requests_to_make if errors prevented some attempts
    # or if worker logic changes. For now, it's the sum of outcomes.

    rps = 0
    if overall_duration_s > 0 and actual_total_requests > 0:
        rps = actual_total_requests / overall_duration_s

    min_ms = 0
    max_ms = 0
    avg_ms = 0

    if all_response_times_ns:
        min_ms = min(all_response_times_ns) / 1_000_000.0
        max_ms = max(all_response_times_ns) / 1_000_000.0
        # Average of all recorded response times (includes successes and potentially errors if recorded)
        avg_ms = statistics.mean(all_response_times_ns) / 1_000_000.0
        # If you only want average of successful requests:
        # avg_ms_successful = (total_duration_ns_overall / success_count / 1_000_000.0) if success_count > 0 else 0

    logger.info(
        "----------------------------------------------------------------------"
    )
    logger.info(f"✅ Test completed in {overall_duration_ms:.2f} ms")
    logger.info(
        f"Total requests processed: {actual_total_requests}"
    )  # Or use total_requests_to_make if that's preferred
    logger.info(f"  -> Successes ✅: {success_count}")
    logger.info(f"  -> Failures ❌: {failure_count}")
    logger.info(f"Performance: ~{rps:.2f} requests/second (RPS)")
    logger.info(
        f"Response times (ms): min {min_ms:.2f} | avg {avg_ms:.2f} | max {max_ms:.2f}"
    )


if __name__ == "__main__":
    main()
