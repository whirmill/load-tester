#!/usr/bin/env bash
set -euo pipefail

# ---------------- Configuration ----------------
# Load .env if present
if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
fi

NUM_THREADS=${NUM_THREADS:-20}
REQUESTS_PER_THREAD=${REQUESTS_PER_THREAD:-50}
TARGET_URL=${TARGET_URL:-http://localhost:3000/api/foo}
AUTH_TOKEN=${AUTH_TOKEN:-}
PAYLOAD_FILE=${PAYLOAD_FILE:-payload.json}

if [[ ! -f $PAYLOAD_FILE ]]; then
    echo "Warning: $PAYLOAD_FILE not found. Requests will have an empty body." >&2
    PAYLOAD_BYTES=""
else
    PAYLOAD_BYTES=$(cat "$PAYLOAD_FILE")
fi

echo "🚀 Starting load test (Bash)..."
echo "Threads: $NUM_THREADS, Requests/Thread: $REQUESTS_PER_THREAD, Total: $((NUM_THREADS * REQUESTS_PER_THREAD))"
echo "Target URL: $TARGET_URL"
if [[ -z "$AUTH_TOKEN" ]]; then
    echo "Auth Token: Not set"
else
    echo "Auth Token: Set (hidden)"
fi
printf '%0.s-' {1..70}
echo

TMP_DIR=$(mktemp -d)

# Worker function to be run in a subshell
worker() {
    local tid=$1
    local success=0 failure=0 total_ns=0 min_ns=999999999999999 max_ns=0
    for ((i = 1; i <= REQUESTS_PER_THREAD; i++)); do
        local start_ns=$(date +%s%N)
        local status
        if [[ -z "$AUTH_TOKEN" ]]; then
            status=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$PAYLOAD_BYTES" "$TARGET_URL")
        else
            status=$(curl -s -o /dev/null -w "%{http_code}" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $AUTH_TOKEN" \
                -d "$PAYLOAD_BYTES" "$TARGET_URL")
        fi
        local duration_ns=$(($(date +%s%N) - start_ns))

        if [[ $status == 200 || $status == 201 ]]; then
            success=$((success + 1))
        else
            failure=$((failure + 1))
        fi

        total_ns=$((total_ns + duration_ns))
        if ((duration_ns < min_ns)); then min_ns=$duration_ns; fi
        if ((duration_ns > max_ns)); then max_ns=$duration_ns; fi

        printf 'Thread %2d | Request %3d/%d | Status: %s\n' "$tid" "$i" "$REQUESTS_PER_THREAD" "$status"
    done
    echo "$success $failure $total_ns $min_ns $max_ns" >"$TMP_DIR/thread_${tid}.txt"
}

start_time=$(date +%s%N)

# Launch threads
for ((t = 1; t <= NUM_THREADS; t++)); do
    worker "$t" &
done
wait

end_time=$(date +%s%N)
duration_ms=$(((end_time - start_time) / 1000000))

total_success=0
total_failure=0
total_ns=0
min_ns=999999999999999
max_ns=0
for file in "$TMP_DIR"/thread_*.txt; do
    read -r s f ns mn mx <"$file"
    total_success=$((total_success + s))
    total_failure=$((total_failure + f))
    total_ns=$((total_ns + ns))
    if ((mn < min_ns)); then min_ns=$mn; fi
    if ((mx > max_ns)); then max_ns=$mx; fi
done

rm -rf "$TMP_DIR"

total_requests=$((total_success + total_failure))
if ((duration_ms > 0)); then
    rps=$(awk -v r=$total_requests -v ms=$duration_ms 'BEGIN { printf "%.2f", (r/(ms/1000)) }')
else
    rps=0
fi

if ((total_requests > 0)); then
    avg_ms=$(awk -v ns=$total_ns -v r=$total_requests 'BEGIN { printf "%.2f", (ns/1000000)/r }')
else
    avg_ms=0
fi

printf '%0.s-' {1..70}
echo
printf '✅ Test completed in %.2f ms\n' "$duration_ms"
echo "Total requests: $total_requests"
echo "  -> Successes ✅: $total_success"
echo "  -> Failures  ❌: $total_failure"
printf 'Performance: ~%.2f requests/second (RPS)\n' "$rps"
min_ms=$(awk -v ns=$min_ns 'BEGIN { printf "%.2f", ns/1000000 }')
max_ms=$(awk -v ns=$max_ns 'BEGIN { printf "%.2f", ns/1000000 }')
printf 'Response times (ms): min %s | avg %s | max %s\n' "$min_ms" "$avg_ms" "$max_ms"
