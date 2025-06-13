#!/usr/bin/env perl
use strict;
use warnings;
use threads;
use threads::shared;
use Time::HiRes qw(time);
use LWP::UserAgent;

# ---------------- Environment ----------------

sub load_dotenv {
    my $env_file = '.env';
    return unless -e $env_file;
    open my $fh, '<', $env_file or return;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/;                # Skip comments
        next unless $line =~ /^(\w+)=(.*)$/;     # key=value format
        my ($key, $value) = ($1, $2);
        $value =~ s/^['"]|['"]$//g;             # Remove surrounding quotes
        $ENV{$key} //= $value;                   # Do not overwrite existing ENV
    }
    close $fh;
}

load_dotenv();

my $NUM_THREADS          = $ENV{NUM_THREADS}          // 20;
my $REQUESTS_PER_THREAD  = $ENV{REQUESTS_PER_THREAD}  // 50;
my $TARGET_URL           = $ENV{TARGET_URL}           // 'http://localhost:3000/api/foo';
my $AUTH_TOKEN           = $ENV{AUTH_TOKEN}           // '';
my $PAYLOAD_FILE         = $ENV{PAYLOAD_FILE}         // 'payload.json';

# ---------------- Shared Metrics ----------------

my $success_count     :shared = 0;
my $failure_count     :shared = 0;
my $total_duration_ns :shared = 0;
# Initialize min to a very large value so first comparison will always be lower
my $min_duration_ns   :shared = ~0;
my $max_duration_ns   :shared = 0;

# ---------------- Helper ----------------

sub update_min_max {
    my ($duration_ns) = @_;
    {
        lock $min_duration_ns;
        $min_duration_ns = $duration_ns if $duration_ns < $min_duration_ns;
    }
    {
        lock $max_duration_ns;
        $max_duration_ns = $duration_ns if $duration_ns > $max_duration_ns;
    }
}

sub read_payload {
    return '' unless -e $PAYLOAD_FILE;
    local $/;
    open my $fh, '<', $PAYLOAD_FILE or do { warn "Could not open $PAYLOAD_FILE: $!"; return ''; };
    my $data = <$fh> // '';
    close $fh;
    return $data;
}

# ---------------- Worker ----------------

sub worker {
    my ($thread_id, $payload) = @_;
    my $ua = LWP::UserAgent->new(
        timeout => 30,
        ssl_opts => { verify_hostname => 0 }, # Accept self-signed certs like the other implementations
    );

    for my $i (1 .. $REQUESTS_PER_THREAD) {
        my $start_ns = time() * 1_000_000_000;
        my $req = HTTP::Request->new( 'POST' => $TARGET_URL );
        $req->header('Content-Type' => 'application/json');
        $req->header('Authorization' => "Bearer $AUTH_TOKEN") if $AUTH_TOKEN ne '';
        $req->content($payload);

        my $response = $ua->request($req);
        my $duration_ns = time() * 1_000_000_000 - $start_ns;

        {
            lock $total_duration_ns;
            $total_duration_ns += $duration_ns;
        }
        update_min_max($duration_ns);

        if ($response->is_success) {
            lock $success_count; $success_count++;
        }
        else {
            lock $failure_count; $failure_count++;
        }

        printf "Thread %2d | Request %3d/%d | Status: %s\n",
               $thread_id, $i, $REQUESTS_PER_THREAD, $response->code;
    }
}

# ---------------- Main ----------------

sub main {
    my $payload = read_payload();
    my $total_requests = $NUM_THREADS * $REQUESTS_PER_THREAD;

    print "\x{1F680} Starting load test (Perl)...\n";   # Rocket emoji
    print "Threads: $NUM_THREADS, Requests/Thread: $REQUESTS_PER_THREAD, Total: $total_requests\n";
    print "Target URL: $TARGET_URL\n";
    if ($AUTH_TOKEN eq '') { print "Auth Token: Not set\n"; }
    else                  { print "Auth Token: Set (hidden)\n"; }
    print "-" x 70, "\n";

    my $start_time = time();

    my @threads;
    for my $id (1 .. $NUM_THREADS) {
        push @threads, threads->create(\&worker, $id, $payload);
    }

    $_->join() for @threads;

    my $duration_s  = time() - $start_time;
    my $duration_ms = $duration_s * 1000;

    my $actual_requests = $success_count + $failure_count;
    my $rps = $duration_s > 0 ? $actual_requests / $duration_s : 0;
    my $avg_ms = $actual_requests > 0 ? ($total_duration_ns / $actual_requests) / 1_000_000 : 0;
    my $min_ms = $min_duration_ns == ~0 ? 0 : $min_duration_ns / 1_000_000;
    my $max_ms = $max_duration_ns / 1_000_000;

    print "-" x 70, "\n";
    printf "\x{2705} Test completed in %.2f ms\n", $duration_ms; # Check-mark emoji
    print  "Total requests: $actual_requests\n";
    print  "  -> Successes \x{2705}: $success_count\n";
    print  "  -> Failures  \x{274C}: $failure_count\n";
    printf "Performance: ~%.2f requests/second (RPS)\n", $rps;
    printf "Response times (ms): min %.2f | avg %.2f | max %.2f\n", $min_ms, $avg_ms, $max_ms;
}

main(); 