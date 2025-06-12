# HTTP Load Tester Collection

HTTP load testing tool with implementations in Go, Rust, Zig, and Python. This repository explores different approaches to building high-performance load testers, providing tools to benchmark web services and compare language/runtime characteristics for this type of workload. Key metrics like RPS, success/failure counts, and response latencies are tracked.

## Implementations

This repository contains separate implementations of the load tester in the following languages:

*   **Go:** See the `go/` directory.
*   **Rust:** See the `rust/` directory.
*   **Zig:** See the `zig/` directory.
*   **Python:** See the `python/` directory.
*   **TypeScript/Node.js:** See the `typescript/` directory.

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
*   `npm` (Node Package Manager, usually comes with Node.js) or `yarn`.

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
npm install
# or if you use yarn: yarn install

# Compile TypeScript to JavaScript (creates a dist/ directory)
npm run build
# or yarn build

# Run the load tester (executes the compiled JavaScript in dist/)
npm start
# or yarn start

# Alternatively, to run directly using ts-node (for development, skips build step)
# npm run dev
# or yarn dev
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

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue.

## License

*(Consider adding a license file, e.g., MIT, Apache 2.0. If so, mention it here.)* 