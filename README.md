# HTTP Load Tester Collection

HTTP load testing tool with implementations in Go, Rust, Zig, and Python. This repository explores different approaches to building high-performance load testers, providing tools to benchmark web services and compare language/runtime characteristics for this type of workload. Key metrics like RPS, success/failure counts, and response latencies are tracked.

## Implementations

This repository contains separate implementations of the load tester in the following languages:

*   **Go:** See the `go/` directory.
*   **Rust:** See the `rust/` directory.
*   **Zig:** See the `zig/` directory.
*   **Python:** See the `python/` directory.
*   **TypeScript/Node.js:** See the `typescript/` directory.
*   **Elixir:** See the `elixir/` directory.
*   **Perl:** See the `perl/` directory.
*   **Bash:** See the `bash/` directory.

## Features (General)

While specific features might vary slightly between implementations, the general goals include:

*   Configurable number of concurrent threads/workers.
*   Configurable number of requests per thread.
*   Customizable target URL.
*   Support for authentication tokens (e.g., Bearer token).
*   Collection and display of performance metrics.
*   Payload for POST requests (e.g., from `payload.json`).

## Metrics Collected

The load testers aim to collect and report the following metrics:

*   **Total Test Duration:** Overall time taken for the test to complete.
*   **Total Requests:** The total number of requests made.
*   **Successful Requests:** Count of requests that completed successfully (e.g., HTTP 200 OK, 201 Created).
*   **Failed Requests:** Count of requests that failed.
*   **Requests Per Second (RPS):** The rate at which requests were processed.
*   **Response Time Statistics (ms):**
    *   Minimum response time.
    *   Average response time.
    *   Maximum response time.

## Directory Structure

```
load-tester/
├── go/             # Go implementation
│   ├── main.go
│   └── payload.json  (expected in go/)
├── rust/           # Rust implementation
│   ├── src/
│   │   └── main.rs
│   └── payload.json  (expected in rust/)
├── zig/            # Zig implementation
│   ├── src/
│   │   ├── main.zig
│   │   └── payload.json  (expected in zig/src/)
│   └── .env            (expected in zig/)
├── python/         # Python implementation
│   ├── main.py
│   ├── requirements.txt
│   ├── payload.json  (expected in python/)
│   └── .env            (expected in python/)
└── typescript/     # TypeScript/Node.js implementation
    ├── src/
    │   └── main.ts
    ├── package.json
    ├── tsconfig.json
    ├── payload.json  (expected in typescript/)
    └── .env            (expected in typescript/)
├── elixir/         # Elixir implementation
│   ├── mix.exs
│   ├── lib/
│   │   ├── load_tester.ex
│   │   └── load_tester/
│   │       └── worker.ex
│   ├── payload.json  (expected in elixir/)
│   ├── .env_example    (example for .env in elixir/)
│   └── .env            (expected in elixir/)
├── perl/           # Perl implementation
│   ├── main.pl
│   ├── payload.json  (expected in perl/)
│   └── .env            (expected in perl/)
├── bash/           # Bash implementation
│   ├── load_test.sh
│   ├── payload.json  (expected in bash/)
│   └── .env            (expected in bash/)
```

---

## Zig Implementation (`zig/`)

The Zig version utilizes `std.http.Client` for making HTTP requests and `dotenv.zig` for managing configuration through a `.env` file. The JSON payload is embedded into the executable at compile time.

### Prerequisites

*   Zig compiler (e.g., version 0.14.1 or later). You can download it from [ziglang.org](https://ziglang.org/download/).

### Configuration

1.  Create a `.env` file in the `zig/` directory with the following variables:

    ```dotenv
    # Number of concurrent threads to use
    NUM_THREADS=20

    # Number of requests each thread will make
    REQUESTS_PER_THREAD=50

    # Target URL for the load test
    TARGET_URL="http://localhost:3000/api/foo"

    # (Optional) Authentication token (Bearer token)
    AUTH_TOKEN=""
    ```
2.  Ensure a `payload.json` file is present in the `zig/src/` directory. This file contains the JSON body for POST requests and will be embedded by the compiler.

### Building and Running

Navigate to the `zig/` directory and run:

```bash
zig build run
```
This command will compile (embedding `zig/src/payload.json`) and run the load tester. Ensure the `.env` file is configured in `zig/`.

### Example Output (Zig)

```
info: 🚀 Starting load test (Zig v0.14+ with std.http.Client & dotenv.zig)...
info: Threads: 20, Requests/Thread: 50, Total: 1000
info: Target URL: http://localhost:3000/api/foo
info: Auth Token: Not set
info: ----------------------------------------------------------------------
... (individual request logs) ...
info: ----------------------------------------------------------------------
info: ✅ Test completed in 12675.31 ms
info: Total requests: 1000
info:   -> Successes ✅: 1000
info:   -> Failures ❌: 0
info: Performance: ~78.90 requests/second (RPS)
info: Response times (ms): min 190.21 | avg 249.48 | max 870.09
```

---

## Go Implementation (`go/`)

The Go version uses the standard `net/http` package and `github.com/joho/godotenv` for configuration.

### Prerequisites

*   Go (e.g., version 1.18 or newer).

### Configuration

1.  Create a `.env` file in the `go/` directory with the following variables (or set them as environment variables):

    ```dotenv
    # Number of concurrent threads to use
    NUM_THREADS=20

    # Number of requests each thread will make
    REQUESTS_PER_THREAD=50

    # Target URL for the load test
    TARGET_URL="http://localhost:3000/api/foo"

    # (Optional) Authentication token (Bearer token)
    AUTH_TOKEN=""
    ```
2.  Ensure a `payload.json` file is present in the `go/` directory.

### Building and Running

Navigate to the `go/` directory and run:

```bash
# Build the executable
go build -o go_load_tester main.go

# Run the load tester
./go_load_tester
```
Ensure the `.env` file (if used) and `payload.json` are in the `go/` directory when running.

---

## Rust Implementation (`rust/`)

The Rust version uses the `reqwest` crate for HTTP requests and the `dotenv` crate for configuration.

### Prerequisites

*   Rust (e.g., latest stable version).
*   Cargo (Rust's package manager).

### Configuration

1.  Create a `.env` file in the `rust/` directory with the following variables (or set them as environment variables):

    ```dotenv
    # Number of concurrent threads to use
    NUM_THREADS=20

    # Number of requests each thread will make
    REQUESTS_PER_THREAD=50

    # Target URL for the load test
    TARGET_URL="http://localhost:3000/api/foo"

    # (Optional) Authentication token (Bearer token)
    AUTH_TOKEN=""
    ```
2.  Ensure a `payload.json` file is present in the `rust/` directory.

### Building and Running

Navigate to the `rust/` directory and run:

```bash
# Build the executable (optimized release build)
cargo build --release

# Run the load tester
./target/release/rust_load_tester
```
Ensure the `.env` file (if used) and `payload.json` are in the `rust/` directory when running the compiled executable.

---

## Python Implementation (`python/`)

The Python version uses the `requests` library for HTTP calls, `python-dotenv` for configuration, and `threading` for concurrency.

### Prerequisites

*   Python (e.g., version 3.8 or newer recommended).
*   `pip` (Python package installer).

### Configuration

1.  Create a `.env` file in the `python/` directory with the following variables (or set them as environment variables):

    ```dotenv
    # Number of concurrent threads to use
    NUM_THREADS=20

    # Number of requests each thread will make
    REQUESTS_PER_THREAD=50

    # Target URL for the load test
    TARGET_URL="http://localhost:3000/api/foo"

    # (Optional) Authentication token (Bearer token)
    AUTH_TOKEN=""
    ```
2.  Ensure a `payload.json` file is present in the `python/` directory.

### Building and Running

Navigate to the `python/` directory and run:

```bash
# Install dependencies
pip install -r requirements.txt

# Run the load tester
python main.py
```
Ensure the `.env` file (if used) and `payload.json` are in the `python/` directory when running.

### Example Output (Python)

```
YYYY-MM-DD HH:MM:SS INFO     🚀 Starting load test (Python)...
YYYY-MM-DD HH:MM:SS INFO     Threads: 20, Requests/Thread: 50, Total: 1000
YYYY-MM-DD HH:MM:SS INFO     Target URL: http://localhost:3000/api/foo
YYYY-MM-DD HH:MM:SS INFO     Auth Token: Not set
----------------------------------------------------------------------
... (individual request logs) ...
----------------------------------------------------------------------
YYYY-MM-DD HH:MM:SS INFO     ✅ Test completed in 12345.67 ms
YYYY-MM-DD HH:MM:SS INFO     Total requests processed: 1000
YYYY-MM-DD HH:MM:SS INFO       -> Successes ✅: 1000
YYYY-MM-DD HH:MM:SS INFO       -> Failures ❌: 0
YYYY-MM-DD HH:MM:SS INFO     Performance: ~81.00 requests/second (RPS)
YYYY-MM-DD HH:MM:SS INFO     Response times (ms): min 100.00 | avg 120.00 | max 250.00
```

---

## TypeScript/Node.js Implementation (`typescript/`)

The TypeScript/Node.js version uses `axios` for HTTP requests, `dotenv` for configuration, and Node.js `worker_threads` for concurrency. It requires compilation from TypeScript to JavaScript before running.

### Prerequisites

*   Node.js (e.g., LTS version, v18.x or v20.x or newer recommended).
*   `pnpm` (Performant npm). You can install it following the instructions at [pnpm.io](https://pnpm.io/installation).

### Configuration

1.  Create a `.env` file in the `typescript/` directory with the following variables:

    ```dotenv
    # Number of concurrent worker threads to use
    NUM_THREADS=20

    # Number of requests each thread will make
    REQUESTS_PER_THREAD=50

    # Target URL for the load test
    TARGET_URL="http://localhost:3000/api/foo"

    # (Optional) Authentication token (Bearer token)
    AUTH_TOKEN=""
    ```
2.  Ensure a `payload.json` file is present in the `typescript/` directory. This file contains the JSON body for POST requests.

### Building and Running

Navigate to the `typescript/` directory and run:

```bash
# Install dependencies (run this once initially)
pnpm install

# Compile TypeScript to JavaScript (creates a dist/ directory)
pnpm run build

# Run the load tester (executes the compiled JavaScript in dist/)
pnpm start

# Alternatively, to run directly using ts-node (for development, skips build step)
# pnpm run dev
```
Ensure the `.env` file and `payload.json` are in the `typescript/` directory when running.

### Example Output (TypeScript/Node.js)

```
🚀 Starting load test (TypeScript/Node.js)...
Threads: 20, Requests/Thread: 50, Total: 1000
Target URL: http://localhost:3000/api/foo
Auth Token: Not set
----------------------------------------------------------------------
Thread  1 | Request   1/50 | Status: 200
Thread  2 | Request   1/50 | Status: 200
... (more individual request logs) ...
Thread 20 | Request  50/50 | Status: 200
----------------------------------------------------------------------
✅ Test completed in 1350.78 ms
Total requests processed: 1000
  -> Successes ✅: 1000
  -> Failures ❌: 0
Performance: ~740.31 requests/second (RPS)
Response times (ms): min 5.21 | avg 12.87 | max 45.03
```

---

## Elixir Implementation (`elixir/`)

The Elixir version uses the `HTTPoison` library for HTTP requests and `Dotenv` for configuration. It leverages Elixir's concurrency model with `GenServer` for worker management.

### Prerequisites

*   Elixir (e.g., version 1.12 or newer). You can find installation instructions on [elixir-lang.org](https://elixir-lang.org/install.html).
*   Mix (Elixir's build tool, comes with Elixir).

### Configuration

1.  Navigate to the `elixir/` directory.
2.  Copy `.env_example` to `.env` (i.e., `cp .env_example .env`).
3.  Edit the `.env` file with your desired configuration:

    ```dotenv
    TARGET_URL=http://localhost:8080/test
    REQUESTS_PER_USER=100
    CONCURRENT_USERS=10
    # PAYLOAD_PATH=payload.json # Optional, defaults to payload.json in the elixir/ directory
    ```
4.  Ensure a `payload.json` file is present in the `elixir/` directory. This file contains the JSON body for POST requests. An example is provided.

### Building and Running

Navigate to the `elixir/` directory and run the following commands:

```bash
# Fetch dependencies
mix deps.get

# Compile the project (optional, mix run will compile if needed)
mix compile

# Run the load tester as an escript
# This will compile and create a self-contained executable script.
# The .env file needs to be in the directory where you run the escript,
# or you can set environment variables directly.
mix escript.build
./load_tester 
# OR, to run directly with mix (slower startup, but good for development):
# mix run -e "LoadTester.main([])"
```
Ensure the `.env` file (if used) and `payload.json` are in the `elixir/` directory when running.

### Example Output (Elixir)

```
info: Starting load test with 10 concurrent users, 100 requests each.
info: Target URL: http://localhost:8080/test
# ... (potential worker logs if enabled, or other info messages) ...
info: ---- Load Test Results ----
info: Total requests: 1000
info: Successful requests: 1000
info: Failed requests: 0
info: Total duration: 5.23s
info: Requests per second (RPS): 191.20
info: Average request duration (from workers): 45.12ms
```

---

## Perl Implementation (`perl/`)

The Perl version prioritizes portability and can run on a default Perl installation. If the optional [Furl](https://metacpan.org/pod/Furl) module is available it will be used for higher throughput; otherwise it falls back to `LWP::UserAgent`.

### Prerequisites

*   Perl 5.32 or newer (threads enabled in the build).
*   Recommended CPAN modules:
    *   `Try::Tiny` (small dependency, used to detect Furl).
    *   `Furl` **(optional but faster)**.
    *   `LWP::UserAgent` (already in many Perl distributions).

Install them with `cpanm Try::Tiny Furl` or your preferred CPAN client.

### Configuration

1.  Create a `.env` file in the `perl/` directory with the following variables (or set them as environment variables):

    ```dotenv
    # Number of concurrent threads to use
    NUM_THREADS=20

    # Number of requests each thread will make
    REQUESTS_PER_THREAD=50

    # Target URL for the load test
    TARGET_URL="http://localhost:3000/api/foo"

    # (Optional) Authentication token (Bearer token)
    AUTH_TOKEN=""
    ```
2.  Ensure a `payload.json` file is present in the `perl/` directory. This file contains the JSON body for POST requests.

### Running

Navigate to the `perl/` directory and run:

```bash
# Execute directly with Perl
perl main.pl

# If you want the best performance, be sure Furl is installed:
cpanm Furl   # once, optional but recommended
perl main.pl
```

Ensure the `.env` file (if used) and `payload.json` are in the `perl/` directory when running.

### Example Output (Perl)

```
🚀 Starting load test (Perl)...
Threads: 20, Requests/Thread: 50, Total: 1000
Target URL: http://localhost:3000/api/foo
Auth Token: Not set
----------------------------------------------------------------------
Thread  1 | Request   1/50 | Status: 200
Thread  2 | Request   1/50 | Status: 200
... (more individual request logs) ...
Thread 20 | Request  50/50 | Status: 200
----------------------------------------------------------------------
✅ Test completed in 2175.42 ms
Total requests: 1000
  -> Successes ✅: 1000
  -> Failures ❌: 0
Performance: ~459.76 requests/second (RPS)
Response times (ms): min 6.45 | avg 27.12 | max 73.81
```

---

## Bash Implementation (`bash/`)

La versione Bash è pensata per la massima portabilità: richiede solo `bash`, `curl` e gli strumenti POSIX standard (`awk`, `date`, `mktemp`). Ogni thread viene eseguito come subshell in background, con metriche aggregate a fine test.

### Prerequisiti

*   Unix-like shell con `bash` 4.x o superiore.
*   `curl`, `awk`, `date` con supporto nanosecondi (`date +%s%N`).

### Configurazione

1.  Creare (facoltativo) un file `.env` nella directory `bash/` con le variabili:

    ```dotenv
    NUM_THREADS=20
    REQUESTS_PER_THREAD=50
    TARGET_URL="http://localhost:3000/api/foo"
    AUTH_TOKEN=""
    PAYLOAD_FILE=payload.json
    ```
2.  Aggiungere `payload.json` nella stessa directory se si desidera inviare un corpo JSON; se assente, verrà inviata una richiesta vuota.

### Esecuzione

```bash
cd bash
chmod +x load_test.sh   # solo la prima volta
./load_test.sh
```

### Output di esempio (Bash)

```
🚀 Starting load test (Bash)...
Threads: 20, Requests/Thread: 50, Total: 1000
Target URL: http://localhost:3000/api/foo
Auth Token: Not set
----------------------------------------------------------------------
Thread  1 | Request   1/50 | Status: 200
Thread  2 | Request   1/50 | Status: 200
... (altri log) ...
Thread 20 | Request  50/50 | Status: 200
----------------------------------------------------------------------
✅ Test completed in 4230.11 ms
Total requests: 1000
  -> Successes ✅: 1000
  -> Failures  ❌: 0
Performance: ~236.44 requests/second (RPS)
Response times (ms): min 8.57 | avg 39.82 | max 110.24
```

---

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

*(Consider adding a license file, e.g., MIT, Apache 2.0. If so, mention it here.)* 