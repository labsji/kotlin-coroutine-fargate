# BACKLOG.md — Autonomous Agent Task Queue

Pick the top unchecked item, implement per `.kiro/steering/workflow.md`, open PR, mark done.

---

## Priority 1 (next cycle)

- [ ] **PIN-001: Add PIN validation endpoint (Lab 5)**
  Add `GET /pin/lab/5?concurrent=N&parallelism=P` endpoint.
  - Simulates PIN validation: `delay(10)` (IO phase) + CPU hash check (~5ms)
  - Launches `concurrent` coroutines with `limitedParallelism(P)`
  - Returns JSON: `{"lab":5,"concurrent":N,"parallelism":P,"durationMs":D,"p50ms":X,"p95ms":Y,"p99ms":Z,"throughput_per_sec":T}`
  - Create `PinLab.kt` in the same package
  - Register route in `Application.kt` routing block
  - Add to the `GET /` index listing

- [ ] **VIZ-001: Add PIN lab option to viz UI dropdown**
  In `VizUi.kt`, add `<option value="pin/lab/5">PIN Validation (Lab 5)</option>` to the lab selector `<select>`.
  Also update the results table headers to show p50/p95/p99 when PIN lab is selected.

- [ ] **DOC-001: Add troubleshooting section to README**
  Add a "Troubleshooting" section at the bottom of `README.md` covering:
  - Port 8080 already in use
  - WSL2/Docker not found
  - Gradle build fails (JDK version mismatch)
  - Fargate tasks stuck at 0 (ecsTaskExecutionRole fix)
  - CloudWatch metrics not appearing (ingestion lag)

## Priority 2

- [ ] **DOC-002: Add "Supported Labs" summary table to README**
  After the "Quick Start" section, add a table listing all endpoints (Labs 1-4, Video Labs 7-10, PIN Lab 5, Dashboard, Viz) with a one-line description and example curl for each.

- [ ] **CODE-001: Add /health endpoint**
  Add `GET /health` that returns `{"status":"ok","uptime_seconds":N,"version":"1.0.0"}`.
  Useful for Fargate health checks and confirming the app is running after deploy.

- [ ] **CODE-002: Add timing endpoint for JIT warm-up demo**
  Add `GET /demo/timing?pins=N` that:
  - Runs N sequential PIN validations, measures CPU phase and IO phase separately
  - Then runs N parallel PIN validations with `limitedParallelism(2)`
  - Returns comparison JSON showing sequential vs parallel durations
  - Purpose: demonstrates JVM JIT warm-up and suspension behavior

- [ ] **SCRIPT-001: Add deploy-fargate-single.sh convenience script**
  Currently `deploy-fargate.sh` exists but `deploy-multi.sh` is the main one.
  Create a simplified `deploy-single.sh` that deploys one Fargate task with configurable CPU:
  ```bash
  ./deploy-single.sh 1024  # deploys with 1024 CPU units
  ```
  Prints the public IP when ready. Useful for quick single-config testing.

## Priority 3

- [ ] **DOC-003: Add architecture diagram to README**
  Add an ASCII diagram showing: Ktor App → Fargate (multiple configs) → Viz UI → Student Browser.
  Similar to the one in SPEC-viz-ui.md but simplified for the README context.

- [ ] **CODE-003: Dockerfile — upgrade to Java 21**
  The `build.gradle.kts` `ktor.docker` block says Java 17 but the actual Dockerfile uses Corretto 21.
  Fix the gradle config to match: `jreVersion.set(JavaVersion.VERSION_21)`.
  Also update any comments referencing Java 17.

- [ ] **CODE-004: Add structured logging**
  Replace `println` calls (if any) with SLF4J logger.
  Add a `logback.xml` config that outputs JSON-formatted logs (useful for CloudWatch Logs Insights).
  Keep it simple — INFO level for requests, DEBUG for lab internals.

---

## Rules for the automation agent

1. Pick ONE item per run
2. Create a feature branch: `auto/<item-id>` (e.g., `auto/pin-001`)
3. Implement following the conventions in `.kiro/steering/workflow.md`
4. Run `./gradlew build --no-daemon -q` — build must pass for code changes
5. Open PR with title: `[BACKLOG] <item-id>: <description>`
6. Mark the item `[x]` in the PR's changes to BACKLOG.md
7. Do NOT merge — human reviews and merges
