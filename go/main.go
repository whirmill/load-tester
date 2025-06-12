package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/joho/godotenv"
)

var (
	totalDurationNs   uint64
	minDurationNs     uint64 = ^uint64(0) // initialize to max uint64
	maxDurationNs     uint64
	successCount      uint64
	failureCount      uint64
	numThreads        int
	requestsPerThread int
	targetURL         string
	authToken         string
)

func getenvInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok {
		if parsed, err := strconv.Atoi(v); err == nil {
			return parsed
		}
		log.Printf("Warning: could not parse env var %s as int: %s. Using default %d", key, v, def)
	}
	return def
}

func getenvStr(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	if def == "" && key != "AUTH_TOKEN" { // Auth token can be empty for some tests
		log.Printf("Warning: env var %s is not set and no default value provided", key)
	}
	return def
}

func init() {
	// load .env if present, ignore error if missing
	err := godotenv.Load()
	if err != nil {
		log.Println("No .env file found, using defaults or environment variables")
	}

	numThreads = getenvInt("NUM_THREADS", 20)
	requestsPerThread = getenvInt("REQUESTS_PER_THREAD", 50)
	targetURL = getenvStr("TARGET_URL", "http://localhost:3000/api/foo")
	authToken = getenvStr("AUTH_TOKEN", "") // Default to empty, can be set in .env or actual env

	if targetURL == "" {
		log.Fatal("TARGET_URL must be set either in .env or as an environment variable")
	}
}

func updateMin(val uint64) {
	for {
		old := atomic.LoadUint64(&minDurationNs)
		if val >= old {
			return
		}
		if atomic.CompareAndSwapUint64(&minDurationNs, old, val) {
			return
		}
	}
}

func updateMax(val uint64) {
	for {
		old := atomic.LoadUint64(&maxDurationNs)
		if val <= old {
			return
		}
		if atomic.CompareAndSwapUint64(&maxDurationNs, old, val) {
			return
		}
	}
}

func worker(threadID int, payload []byte, wg *sync.WaitGroup) {
	defer wg.Done()

	client := &http.Client{
		Transport: &http.Transport{DisableKeepAlives: true},
		Timeout:   0, // No timeout for individual requests, overall controlled by context if needed
	}

	for i := range requestsPerThread {
		reqNum := i + 1

		req, err := http.NewRequest(http.MethodPost, targetURL, bytes.NewReader(payload))
		if err != nil {
			log.Printf("Thread %2d | Request %3d/%d | build error: %v", threadID, reqNum, requestsPerThread, err)
			atomic.AddUint64(&failureCount, 1)
			continue
		}
		if authToken != "" {
			req.Header.Set("Authorization", "Bearer "+authToken)
		}
		req.Header.Set("Content-Type", "application/json")

		start := time.Now()
		resp, err := client.Do(req)
		if err != nil {
			log.Printf("Thread %2d | Request %3d/%d | send error: %v", threadID, reqNum, requestsPerThread, err)
			atomic.AddUint64(&failureCount, 1)
			continue
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()

		dur := time.Since(start)
		ns := uint64(dur.Nanoseconds())
		atomic.AddUint64(&totalDurationNs, ns)
		updateMin(ns)
		updateMax(ns)

		if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
			atomic.AddUint64(&successCount, 1)
		} else {
			atomic.AddUint64(&failureCount, 1)
		}

		log.Printf("Thread %2d | Request %3d/%d | Status: %s", threadID, reqNum, requestsPerThread, resp.Status)
	}
}

func main() {
	payload, err := os.ReadFile("payload.json")
	if err != nil {
		log.Fatalf("Cannot read payload.json: %v", err)
	}

	runtime.GOMAXPROCS(runtime.NumCPU())

	totalRequests := numThreads * requestsPerThread
	log.Printf("🚀 Starting load test (Go)...")
	log.Printf("Threads: %d, Requests/Thread: %d, Total: %d", numThreads, requestsPerThread, totalRequests)
	log.Printf("Target URL: %s", targetURL)
	if authToken == "" {
		log.Println("Auth Token: Not set")
	} else {
		log.Println("Auth Token: Set (hidden)")
	}
	log.Printf("----------------------------------------------------------------------")

	start := time.Now()

	var wg sync.WaitGroup
	wg.Add(numThreads)

	for i := range numThreads {
		go worker(i+1, payload, &wg)
	}

	wg.Wait()

	duration := time.Since(start)
	durationMs := float64(duration.Milliseconds())
	var rps float64
	if duration.Seconds() > 0 {
		rps = float64(totalRequests) / duration.Seconds()
	}

	avgMs := float64(0)
	if totalRequests > 0 {
		avgMs = float64(totalDurationNs) / float64(totalRequests) / 1_000_000.0
	}

	minFinal := atomic.LoadUint64(&minDurationNs)
	minMs := float64(0)
	if minFinal != ^uint64(0) { // check if it was updated from initial max value
		minMs = float64(minFinal) / 1_000_000.0
	}

	maxMs := float64(atomic.LoadUint64(&maxDurationNs)) / 1_000_000.0

	log.Printf("----------------------------------------------------------------------")
	log.Printf("✅ Test completed in %.2f ms", durationMs)
	log.Printf("Total requests: %d", totalRequests)
	log.Printf("  -> Success ✅: %d", atomic.LoadUint64(&successCount))
	log.Printf("  -> Failure ❌: %d", atomic.LoadUint64(&failureCount))
	log.Printf("Performance: ~%.2f requests/second (RPS)", rps)
	log.Printf("Response times (ms): min %.2f | avg %.2f | max %.2f", minMs, avgMs, maxMs)

	fmt.Println()
}
