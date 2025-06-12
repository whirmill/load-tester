use dotenv::dotenv;
use std::env;
use std::fs;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Instant;

// These will be loaded from .env or default values
struct Config {
    num_threads: usize,
    requests_per_thread: usize,
    target_url: String,
    auth_token: String,
}

static TOTAL_DURATION_NS: AtomicU64 = AtomicU64::new(0);
static MIN_DURATION_NS: AtomicU64 = AtomicU64::new(u64::MAX);
static MAX_DURATION_NS: AtomicU64 = AtomicU64::new(0);

static SUCCESS_COUNT: AtomicUsize = AtomicUsize::new(0);
static FAILURE_COUNT: AtomicUsize = AtomicUsize::new(0);

fn update_min(val: u64) {
    loop {
        let old = MIN_DURATION_NS.load(Ordering::Relaxed);
        if val >= old {
            break;
        }
        if MIN_DURATION_NS
            .compare_exchange(old, val, Ordering::Relaxed, Ordering::Relaxed)
            .is_ok()
        {
            break;
        }
    }
}

fn update_max(val: u64) {
    loop {
        let old = MAX_DURATION_NS.load(Ordering::Relaxed);
        if val <= old {
            break;
        }
        if MAX_DURATION_NS
            .compare_exchange(old, val, Ordering::Relaxed, Ordering::Relaxed)
            .is_ok()
        {
            break;
        }
    }
}

fn get_env_usize(key: &str, default: usize) -> usize {
    match env::var(key) {
        Ok(val_str) => match val_str.parse::<usize>() {
            Ok(val) => val,
            Err(_) => {
                println!(
                    "Warning: could not parse env var {} as usize: {}. Using default {}",
                    key, val_str, default
                );
                default
            }
        },
        Err(_) => default,
    }
}

fn get_env_string(key: &str, default: &str) -> String {
    match env::var(key) {
        Ok(val) if !val.is_empty() => val,
        _ => {
            if default.is_empty() && key != "AUTH_TOKEN" {
                // Auth token can be empty
                println!(
                    "Warning: env var {} is not set and no default value provided",
                    key
                );
            }
            default.to_string()
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok(); // Load .env file, ignore if not found

    let config = Config {
        num_threads: get_env_usize("NUM_THREADS", 20),
        requests_per_thread: get_env_usize("REQUESTS_PER_THREAD", 50),
        target_url: get_env_string("TARGET_URL", "http://localhost:3000/api/foo"),
        auth_token: get_env_string("AUTH_TOKEN", ""),
    };

    if config.target_url.is_empty() {
        eprintln!("Error: TARGET_URL must be set either in .env or as an environment variable.");
        std::process::exit(1);
    }

    let payload = fs::read("payload.json")?;

    println!("🚀 Starting load test (Rust)...");
    let total_requests = config.num_threads * config.requests_per_thread;
    println!(
        "Threads: {}, Requests/Thread: {}, Total: {}",
        config.num_threads, config.requests_per_thread, total_requests
    );
    println!("Target URL: {}", config.target_url);
    if config.auth_token.is_empty() {
        println!("Auth Token: Not set");
    } else {
        println!("Auth Token: Set (hidden)");
    }
    println!("----------------------------------------------------------------------");

    let start = Instant::now();

    let payload_arc = Arc::new(payload);
    let mut handles = Vec::with_capacity(config.num_threads);
    let config_arc = Arc::new(config); // Share config across threads

    for thread_id in 1..=config_arc.num_threads {
        let payload_clone = Arc::clone(&payload_arc);
        let current_config = Arc::clone(&config_arc); // Clone Arc for the thread

        let handle = thread::spawn(move || {
            let client = reqwest::blocking::Client::builder()
                .danger_accept_invalid_certs(true) // Consider security implications
                .build()
                .expect("failed to build client");

            for i in 0..current_config.requests_per_thread {
                let req_num = i + 1;
                let start_req = Instant::now();

                let mut request_builder = client
                    .post(&current_config.target_url)
                    .header("Content-Type", "application/json")
                    .body((*payload_clone).clone());

                if !current_config.auth_token.is_empty() {
                    request_builder = request_builder.header(
                        "Authorization",
                        format!("Bearer {}", current_config.auth_token),
                    );
                }

                let res = request_builder.send();

                let dur_ns = start_req.elapsed().as_nanos() as u64;

                TOTAL_DURATION_NS.fetch_add(dur_ns, Ordering::Relaxed);
                update_min(dur_ns);
                update_max(dur_ns);

                match res {
                    Ok(resp) => {
                        if resp.status() == reqwest::StatusCode::OK
                            || resp.status() == reqwest::StatusCode::CREATED
                        {
                            SUCCESS_COUNT.fetch_add(1, Ordering::Relaxed);
                        } else {
                            FAILURE_COUNT.fetch_add(1, Ordering::Relaxed);
                        }
                        println!(
                            "Thread {:>2} | Request {:>3}/{} | Status: {}",
                            thread_id,
                            req_num,
                            current_config.requests_per_thread, // Use config from Arc
                            resp.status()
                        );
                    }
                    Err(err) => {
                        FAILURE_COUNT.fetch_add(1, Ordering::Relaxed);
                        eprintln!(
                            "Thread {:>2} | Request {:>3}/{} | Error: {}",
                            thread_id,
                            req_num,
                            current_config.requests_per_thread,
                            err // Use config from Arc
                        );
                    }
                }
            }
        });
        handles.push(handle);
    }

    for handle in handles {
        handle.join().expect("thread panicked");
    }

    let duration = start.elapsed();
    let duration_ms = duration.as_secs_f64() * 1000.0;

    let rps = if duration.as_secs_f64() > 0.0 {
        (total_requests as f64) / duration.as_secs_f64()
    } else {
        0.0
    };

    let avg_ms = if total_requests > 0 {
        TOTAL_DURATION_NS.load(Ordering::Relaxed) as f64 / total_requests as f64 / 1_000_000.0
    } else {
        0.0
    };

    let min_final_ns = MIN_DURATION_NS.load(Ordering::Relaxed);
    let min_ms = if min_final_ns != u64::MAX {
        min_final_ns as f64 / 1_000_000.0
    } else {
        0.0
    };
    let max_ms = MAX_DURATION_NS.load(Ordering::Relaxed) as f64 / 1_000_000.0;

    println!("----------------------------------------------------------------------");
    println!("✅ Test completed in {:.2} ms", duration_ms);
    println!("Total requests: {}", total_requests);
    println!("  -> Success ✅: {}", SUCCESS_COUNT.load(Ordering::Relaxed));
    println!("  -> Failure ❌: {}", FAILURE_COUNT.load(Ordering::Relaxed));
    println!("Performance: ~{:.2} requests/second (RPS)", rps);
    println!(
        "Response times (ms): min {:.2} | avg {:.2} | max {:.2}",
        min_ms, avg_ms, max_ms
    );

    Ok(())
}
