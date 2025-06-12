import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import axios, { AxiosError } from "axios";
import { Worker, isMainThread, parentPort, workerData } from "worker_threads";

// --- Configuration ---
dotenv.config({ path: path.resolve(__dirname, "../.env") }); // Load .env from typescript/ directory

const NUM_THREADS = parseInt(process.env.NUM_THREADS || "20", 10);
const REQUESTS_PER_THREAD = parseInt(process.env.REQUESTS_PER_THREAD || "50", 10);
const TARGET_URL = process.env.TARGET_URL || "http://localhost:3000/api/foo";
const AUTH_TOKEN = process.env.AUTH_TOKEN || "";
const PAYLOAD_FILE_PATH = path.resolve(__dirname, "../payload.json"); // Assumes payload.json is in typescript/

interface WorkerData {
  threadId: number;
  requestsPerThread: number;
  targetUrl: string;
  authToken: string;
  payloadData: string; // stringified JSON
}

interface WorkerResult {
  type: "metric" | "log" | "errorLog";
  threadId?: number;
  durationNs?: bigint;
  success?: boolean;
  statusCode?: number;
  message?: string;
  reqNum?: number;
  totalReqsInThread?: number;
}

// --- Worker Logic (executed in worker threads) ---
async function workerLogic() {
  if (!parentPort || !workerData) return;

  const { threadId, requestsPerThread, targetUrl, authToken, payloadData } =
    workerData as WorkerData;
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (authToken) {
    headers["Authorization"] = `Bearer ${authToken}`;
  }

  const client = axios.create({
    headers: headers,
    timeout: 30000, // 30 seconds timeout
  });

  for (let i = 0; i < requestsPerThread; i++) {
    const reqNum = i + 1;
    const startTime = process.hrtime.bigint();
    let success = false;
    let statusCode: number | undefined;

    try {
      const response = await client.post(targetUrl, payloadData);
      statusCode = response.status;
      if (response.status === 200 || response.status === 201) {
        success = true;
      }
      parentPort.postMessage({
        type: "log",
        threadId,
        reqNum,
        totalReqsInThread: requestsPerThread,
        message: `Status: ${response.status}`,
      } as WorkerResult);
      // response.data; // consume response body if necessary, for now discarding
    } catch (error) {
      const axiosError = error as AxiosError;
      if (axiosError.response) {
        statusCode = axiosError.response.status;
        parentPort.postMessage({
          type: "errorLog",
          threadId,
          reqNum,
          totalReqsInThread: requestsPerThread,
          message: `Error: ${axiosError.response.status} - ${axiosError.message}`,
        } as WorkerResult);
      } else {
        parentPort.postMessage({
          type: "errorLog",
          threadId,
          reqNum,
          totalReqsInThread: requestsPerThread,
          message: `Error: ${axiosError.message}`,
        } as WorkerResult);
      }
      success = false;
    }
    const endTime = process.hrtime.bigint();
    const durationNs = endTime - startTime;
    parentPort.postMessage({
      type: "metric",
      durationNs,
      success,
      statusCode,
      threadId,
    } as WorkerResult);
  }
}

// --- Main Thread Logic ---
async function main() {
  console.log("🚀 Starting load test (TypeScript/Node.js)...");
  console.log(
    `Threads: ${NUM_THREADS}, Requests/Thread: ${REQUESTS_PER_THREAD}, Total: ${
      NUM_THREADS * REQUESTS_PER_THREAD
    }`
  );
  console.log(`Target URL: ${TARGET_URL}`);
  console.log(`Auth Token: ${AUTH_TOKEN ? "Set (hidden)" : "Not set"}`);
  console.log("----------------------------------------------------------------------");

  let payloadDataString = "{}";
  try {
    if (fs.existsSync(PAYLOAD_FILE_PATH)) {
      payloadDataString = fs.readFileSync(PAYLOAD_FILE_PATH, "utf-8");
    } else {
      console.warn(`Warning: ${PAYLOAD_FILE_PATH} not found. Using empty JSON object as payload.`);
    }
  } catch (err) {
    console.error(`Error reading payload file ${PAYLOAD_FILE_PATH}:`, err);
    process.exit(1);
  }

  const overallStartTime = process.hrtime.bigint();
  let workersDone = 0;

  const allResponseTimesNs: bigint[] = [];
  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < NUM_THREADS; i++) {
    const worker = new Worker(__filename, {
      // __filename refers to the current file (main.ts when run directly, or main.js after compilation)
      workerData: {
        threadId: i + 1,
        requestsPerThread: REQUESTS_PER_THREAD,
        targetUrl: TARGET_URL,
        authToken: AUTH_TOKEN,
        payloadData: payloadDataString,
      } as WorkerData,
    });

    worker.on("message", (result: WorkerResult) => {
      if (result.type === "metric") {
        if (result.durationNs) allResponseTimesNs.push(result.durationNs);
        if (result.success) {
          successCount++;
        } else {
          failureCount++;
        }
      } else if (result.type === "log") {
        console.log(
          `Thread ${result.threadId?.toString().padStart(2, " ")} | Request ${result.reqNum
            ?.toString()
            .padStart(3, " ")}/${result.totalReqsInThread} | ${result.message}`
        );
      } else if (result.type === "errorLog") {
        console.error(
          `Thread ${result.threadId?.toString().padStart(2, " ")} | Request ${result.reqNum
            ?.toString()
            .padStart(3, " ")}/${result.totalReqsInThread} | ${result.message}`
        );
      }
    });

    worker.on("error", (err) => {
      console.error(`Worker error (Thread ${i + 1}):`, err);
      failureCount += REQUESTS_PER_THREAD; // Assume all requests for this worker failed
    });

    worker.on("exit", (code) => {
      workersDone++;
      if (code !== 0) {
        console.error(`Worker (Thread ${i + 1}) stopped with exit code ${code}`);
      }
      if (workersDone === NUM_THREADS) {
        const overallEndTime = process.hrtime.bigint();
        const overallDurationNs = overallEndTime - overallStartTime;
        const overallDurationMs = Number(overallDurationNs / BigInt(1000000));

        const totalProcessedRequests = successCount + failureCount;
        const rps =
          totalProcessedRequests > 0 && overallDurationNs > 0
            ? Number((BigInt(totalProcessedRequests) * BigInt(1000000000)) / overallDurationNs)
            : 0;

        let minMs = 0,
          avgMs = 0,
          maxMs = 0;
        if (allResponseTimesNs.length > 0) {
          minMs = Number(
            allResponseTimesNs.reduce(
              (min, current) => (current < min ? current : min),
              allResponseTimesNs[0]
            ) / BigInt(1000000)
          );
          maxMs = Number(
            allResponseTimesNs.reduce(
              (max, current) => (current > max ? current : max),
              allResponseTimesNs[0]
            ) / BigInt(1000000)
          );
          const sumNs = allResponseTimesNs.reduce((sum, current) => sum + current, BigInt(0));
          avgMs = Number(sumNs / BigInt(allResponseTimesNs.length) / BigInt(1000000));
        }

        console.log("----------------------------------------------------------------------");
        console.log(`✅ Test completed in ${overallDurationMs.toFixed(2)} ms`);
        console.log(`Total requests processed: ${totalProcessedRequests}`);
        console.log(`  -> Successes ✅: ${successCount}`);
        console.log(`  -> Failures ❌: ${failureCount}`);
        console.log(`Performance: ~${rps.toFixed(2)} requests/second (RPS)`);
        console.log(
          `Response times (ms): min ${minMs.toFixed(2)} | avg ${avgMs.toFixed(
            2
          )} | max ${maxMs.toFixed(2)}`
        );
      }
    });
  }
}

if (isMainThread) {
  main().catch((err) => console.error("Main thread error:", err));
} else {
  workerLogic().catch((err) => {
    if (parentPort)
      parentPort.postMessage({
        type: "errorLog",
        message: `Critical worker error: ${err}`,
      } as WorkerResult);
    else console.error("Critical worker error (no parentPort):", err);
    process.exit(1); // Ensure worker exits on unhandled error
  });
}
