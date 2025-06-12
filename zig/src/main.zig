const std = @import("std");
const dotenv = @import("dotenv");

// Structure to hold configuration
const Config = struct {
    num_threads: usize,
    requests_per_thread: usize,
    target_url: []const u8, // Owned by dotenv.Env or default literal
    auth_token: []const u8, // Owned by dotenv.Env or default literal
    parsed_uri: std.Uri,

    // Need to store the allocator used by dotenv to free the strings later
    allocator: ?std.mem.Allocator = null,
    env_map: ?dotenv = null,

    // Make deinit explicit if we have an env_map
    fn deinit(self: *Config) void {
        if (self.env_map) |*env| {
            env.deinit();
        }
        if (self.allocator) |alloc| {
            // Important: dotenv.Env.get() returns slices of memory owned by Env.
            // We should not free target_url and auth_token individually if they came from env.get().
            // dotenv.Env.deinit() handles freeing the memory it allocated.
            // If we created duplicates (e.g. for default values not from env), those would need freeing.
            // However, with env.get() orelse "default", the defaults are string literals, not allocated.
            _ = alloc; // Placeholder if we needed to free duplicated strings.
        }
    }
};

// Global config variable
var g_config: Config = undefined;

// JSON payload is loaded from `payload.json`
const JSON_PAYLOAD = @embedFile("payload.json");
// =============================================================================

const JSON_PAYLOAD_LEN_STR = std.fmt.comptimePrint("{d}", .{JSON_PAYLOAD.len});

// Response time metrics (nanoseconds)
var total_duration_ns = std.atomic.Value(u64).init(0);
var min_duration_ns = std.atomic.Value(u64).init(std.math.maxInt(u64));
var max_duration_ns = std.atomic.Value(u64).init(0);

// Atomic counters to track results in a thread-safe manner
var success_count = std.atomic.Value(usize).init(0);
var failure_count = std.atomic.Value(usize).init(0);

// Function executed by each thread
fn worker(thread_id: usize, allocator: std.mem.Allocator) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var auth_header_value_buf: [1024]u8 = undefined; // Buffer for auth header string
    var auth_header_value_slice: ?[]const u8 = null;

    if (g_config.auth_token.len > 0) {
        // Use a buffer for formatting to avoid another allocation per thread if possible
        const formatted_auth_header = try std.fmt.bufPrint(&auth_header_value_buf, "Bearer {s}", .{g_config.auth_token});
        auth_header_value_slice = formatted_auth_header;
    }

    var base_headers = std.http.Client.Request.Headers{
        .content_type = .{ .override = "application/json" },
        .accept_encoding = .omit,
    };
    if (auth_header_value_slice) |h_val| {
        base_headers.authorization = .{ .override = h_val };
    }

    const extra_hdrs = [_]std.http.Header{};

    for (0..g_config.requests_per_thread) |i| {
        const req_num = i + 1;
        var server_response_header_buffer: [2048]u8 = undefined;
        const start_ns: i128 = std.time.nanoTimestamp();

        var request = client.open(.POST, g_config.parsed_uri, .{
            .server_header_buffer = &server_response_header_buffer,
            .headers = base_headers,
            .extra_headers = &extra_hdrs,
            .keep_alive = false,
        }) catch |err| {
            std.log.err("Thread {d: >2} | Request {d: >3}/{d} | Open error: {any}", .{ thread_id, req_num, g_config.requests_per_thread, err });
            _ = failure_count.fetchAdd(1, .monotonic);
            continue;
        };
        defer request.deinit();

        request.transfer_encoding = .{ .content_length = JSON_PAYLOAD.len };

        request.send() catch |err| {
            std.log.err("Thread {d: >2} | Request {d: >3}/{d} | Send headers error: {any}", .{ thread_id, req_num, g_config.requests_per_thread, err });
            _ = failure_count.fetchAdd(1, .monotonic);
            continue;
        };

        request.writeAll(JSON_PAYLOAD) catch |err| {
            std.log.err("Thread {d: >2} | Request {d: >3}/{d} | Write body error: {any}", .{ thread_id, req_num, g_config.requests_per_thread, err });
            _ = failure_count.fetchAdd(1, .monotonic);
            continue;
        };

        request.finish() catch |err| {
            std.log.err("Thread {d: >2} | Request {d: >3}/{d} | Finish request error: {any}", .{ thread_id, req_num, g_config.requests_per_thread, err });
            _ = failure_count.fetchAdd(1, .monotonic);
            continue;
        };

        request.wait() catch |err| {
            std.log.err("Thread {d: >2} | Request {d: >3}/{d} | Wait error: {any}", .{ thread_id, req_num, g_config.requests_per_thread, err });
            _ = failure_count.fetchAdd(1, .monotonic);
            continue;
        };

        const dur_i128: i128 = std.time.nanoTimestamp() - start_ns;
        const dur: u64 = @intCast(@max(dur_i128, 0));
        _ = total_duration_ns.fetchAdd(dur, .monotonic);
        _ = min_duration_ns.fetchMin(dur, .monotonic);
        _ = max_duration_ns.fetchMax(dur, .monotonic);

        if (request.response.status == .ok or request.response.status == .created) {
            _ = success_count.fetchAdd(1, .monotonic);
        } else {
            _ = failure_count.fetchAdd(1, .monotonic);
        }

        std.log.info("Thread {d: >2} | Request {d: >3}/{d} | Status: {any}", .{ thread_id, req_num, g_config.requests_per_thread, request.response.status });
    }
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer {
        g_config.deinit();
        _ = general_purpose_allocator.deinit();
    }

    var env_map_nullable: ?dotenv = null; // MODIFIED HERE
    const dotenv_init_result = dotenv.init(gpa, ".env"); // Call init

    if (dotenv_init_result) |env_instance| {
        env_map_nullable = env_instance; // Assign if successful
    } else |err| {
        std.log.info("dotenv.init failed (e.g. .env not found): {any}. Using defaults/env vars.", .{err});
        // env_map_nullable remains null in case of error
    }

    // Diagnostic log, can be removed later
    // std.log.debug("dotenv.Env initialized (value: {?}), proceeding to load config strings.", .{env_map_nullable});

    const num_threads_str: []const u8 = blk_num_threads: {
        if (env_map_nullable) |*env| {
            break :blk_num_threads env.get("NUM_THREADS") orelse "20";
        } else {
            break :blk_num_threads "20";
        }
    };
    const num_threads = std.fmt.parseInt(usize, num_threads_str, 10) catch |err| blk_num_threads_fallback: {
        std.log.warn("Failed to parse NUM_THREADS='{s}': {any}. Using default 20.", .{ num_threads_str, err });
        break :blk_num_threads_fallback 20;
    };

    const requests_per_thread_str: []const u8 = blk_req_per_thread: {
        if (env_map_nullable) |*env| {
            break :blk_req_per_thread env.get("REQUESTS_PER_THREAD") orelse "50";
        } else {
            break :blk_req_per_thread "50";
        }
    };
    const requests_per_thread = std.fmt.parseInt(usize, requests_per_thread_str, 10) catch |err| blk_req_fallback: {
        std.log.warn("Failed to parse REQUESTS_PER_THREAD='{s}': {any}. Using default 50.", .{ requests_per_thread_str, err });
        break :blk_req_fallback 50;
    };

    const default_target_url = "http://localhost:3000/api/foo";
    const target_url_str: []const u8 = blk_target_url: {
        if (env_map_nullable) |*env| {
            break :blk_target_url env.get("TARGET_URL") orelse default_target_url;
        } else {
            break :blk_target_url default_target_url;
        }
    };

    if (target_url_str.len == 0) {
        std.log.err("TARGET_URL must be set (e.g. in .env or as environment variable).", .{});
        return error.InvalidConfiguration;
    }

    const auth_token_str: []const u8 = blk_auth_token: {
        if (env_map_nullable) |*env| {
            break :blk_auth_token env.get("AUTH_TOKEN") orelse "";
        } else {
            break :blk_auth_token "";
        }
    };

    const parsed_uri = std.Uri.parse(target_url_str) catch |err| {
        std.log.err("Invalid TARGET_URL: '{s}'. Error: {any}", .{ target_url_str, err });
        return error.InvalidConfiguration;
    };

    g_config = Config{
        .num_threads = num_threads,
        .requests_per_thread = requests_per_thread,
        .target_url = target_url_str,
        .auth_token = auth_token_str,
        .parsed_uri = parsed_uri,
        .allocator = if (env_map_nullable != null) gpa else null,
        .env_map = env_map_nullable,
    };
    // Note: g_config.deinit() is called in the defer block for main's GPA.

    const total_requests = g_config.num_threads * g_config.requests_per_thread;

    std.log.info("🚀 Starting load test (Zig v0.14+ with std.http.Client & dotenv.zig)...", .{});
    std.log.info("Threads: {d}, Requests/Thread: {d}, Total: {d}", .{
        g_config.num_threads,
        g_config.requests_per_thread,
        total_requests,
    });
    std.log.info("Target URL: {s}", .{g_config.target_url});
    if (g_config.auth_token.len == 0) {
        std.log.info("Auth Token: Not set", .{});
    } else {
        std.log.info("Auth Token: Set (hidden)", .{});
    }
    std.log.info("----------------------------------------------------------------------", .{});

    const start_time = std.time.nanoTimestamp();

    // Use ArrayList for threads if NUM_THREADS is not a comptime known value
    var threads = std.ArrayList(std.Thread).init(gpa);
    defer threads.deinit();

    for (0..g_config.num_threads) |i| {
        // Each worker thread now needs its own allocator for its HTTP client.
        // We create a new GPA for each thread for true isolation. (REMOVED for now to fix unused var)
        // var worker_gpa = std.heap.GeneralPurposeAllocator(.{}){};
        // The worker_gpa needs to be deinitialized. This is tricky as threads.append
        // takes ownership. A more robust solution might involve the thread function
        // taking ownership and deinitializing, or using a wrapper struct.
        // For simplicity here, we'll leak it or rely on OS cleanup, which is not ideal.
        // A better approach is needed for long-running apps.
        // However, since these threads are joined, we can deinit after join, but that requires
        // storing the allocators.
        // Let's pass the main gpa's allocator for now, like before.
        try threads.append(try std.Thread.spawn(.{ .allocator = gpa }, worker, .{ i + 1, gpa }));
    }

    for (threads.items) |t| {
        t.join();
    }

    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    const rps = if (duration_ms > 0 and total_requests > 0) @as(f64, @floatFromInt(total_requests)) / (duration_ms / 1000.0) else 0;

    const tot_ns = total_duration_ns.load(.monotonic);
    const avg_ms = if (total_requests > 0) @as(f64, @floatFromInt(tot_ns)) / @as(f64, @floatFromInt(total_requests)) / 1_000_000.0 else 0;

    const min_final_ns = min_duration_ns.load(.monotonic);
    const min_ms = if (min_final_ns != std.math.maxInt(u64)) @as(f64, @floatFromInt(min_final_ns)) / 1_000_000.0 else 0.0;
    const max_ms = if (max_duration_ns.load(.monotonic) > 0) @as(f64, @floatFromInt(max_duration_ns.load(.monotonic))) / 1_000_000.0 else 0.0;

    std.log.info("----------------------------------------------------------------------", .{});
    std.log.info("✅ Test completed in {d:.2} ms", .{duration_ms});
    std.log.info("Total requests: {d}", .{total_requests});
    std.log.info("  -> Successes ✅: {d}", .{success_count.load(.monotonic)});
    std.log.info("  -> Failures ❌: {d}", .{failure_count.load(.monotonic)});
    std.log.info("Performance: ~{d:.2} requests/second (RPS)", .{rps});
    std.log.info("Response times (ms): min {d:.2} | avg {d:.2} | max {d:.2}", .{ min_ms, avg_ms, max_ms });
}
