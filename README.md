# Kotlin Coroutines on AWS — From Laptop to Fargate

Learn Kotlin coroutines by deploying real workloads to AWS and observing how `limitedParallelism`, dispatcher configuration, and coroutine concurrency translate to actual vCPU/memory utilization.

## What You'll Learn

1. What coroutines are (and aren't) — structured concurrency basics
2. Dispatchers: Default, IO, and custom thread pools
3. `limitedParallelism` — controlling concurrency at the coroutine level
4. Semaphore/permits — throttling concurrent work
5. How these map to real vCPU and memory on AWS (Beanstalk / Fargate)

## The Labs

| Lab | What You Do | What You Observe |
|-----|-------------|-----------------|
| 1 | Launch 1000 coroutines on `Dispatchers.Default` | CPU-bound: saturates vCPU count |
| 2 | Launch 1000 coroutines on `Dispatchers.IO` | IO-bound: 64 threads, memory grows |
| 3 | Apply `limitedParallelism(4)` | Only 4 concurrent, rest suspended — CPU stays flat |
| 4 | Use `Semaphore(10)` for rate limiting | Controlled throughput, predictable resource use |
| 5 | Deploy to Beanstalk (0.5 vCPU, 1 vCPU, 2 vCPU) | See how coroutine config interacts with real hardware |
| 6 | Deploy to Fargate (256/512/1024 CPU units) | Same code, different resource profiles |

## Quick Start (Self-Service)

```bash
git clone https://github.com/labsji/kotlin-coroutine-fargate.git
cd kotlin-coroutine-fargate
./gradlew build
./run-local.sh        # Run labs locally, observe with VisualVM or metrics endpoint
./deploy-beanstalk.sh # Deploy to your own AWS account
```

## Quick Start (Premium — CloudShell)

Pre-configured AWS account. No setup needed.

```bash
cd ~/kotlin-coroutine-fargate
./start.sh            # Kiro guides you through the labs
```

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Kotlin App (Ktor + Coroutines)                           │
│                                                           │
│  /lab/1  — 1000 coroutines, Dispatchers.Default           │
│  /lab/2  — 1000 coroutines, Dispatchers.IO                │
│  /lab/3  — 1000 coroutines, limitedParallelism(4)         │
│  /lab/4  — 1000 coroutines, Semaphore(10)                 │
│  /metrics — Prometheus endpoint (CPU, memory, threads)    │
└──────────────────────────────────────────────────────────┘
        │
        ▼ deployed to
┌──────────────────────────────────────────────────────────┐
│  AWS Elastic Beanstalk (Docker)                           │
│  OR                                                       │
│  AWS Fargate (ECS)                                        │
│                                                           │
│  Student varies: vCPU (0.25, 0.5, 1, 2, 4)              │
│                  Memory (512MB, 1GB, 2GB, 4GB)           │
│                                                           │
│  CloudWatch Metrics → observe real utilization            │
└──────────────────────────────────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `src/` | Kotlin app — Ktor server with lab endpoints |
| `TUTORIAL.md` | Full tutorial with explanations |
| `run-local.sh` | Run locally with Docker |
| `deploy-beanstalk.sh` | Deploy to Beanstalk (self-service) |
| `deploy-fargate.sh` | Deploy to Fargate (self-service) |
| `start.sh` | Kiro-guided session (premium) |
| `create-student.sh` | Provision student CloudShell account |
| `cleanup.sh` | Tear down AWS resources |
| `Dockerfile` | Container image |
| `build.gradle.kts` | Kotlin/Ktor project |

## Student Outcome

After completing the labs, you can demonstrate:

1. **"This is what a coroutine does"** — lightweight concurrent unit, suspends without blocking a thread
2. **"This is what happens at different configs"** — show CloudWatch graphs proving that `limitedParallelism(4)` on a 2-vCPU Fargate task uses exactly 4 threads regardless of 1000 launched coroutines
3. **"This is why it matters"** — cost optimization (right-size vCPU), stability (no OOM from unbounded IO), predictability (semaphore = controlled throughput)
