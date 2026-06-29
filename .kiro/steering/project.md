# Project: Kotlin Coroutines on AWS

## Overview

A hands-on tutorial application that teaches Kotlin coroutine concurrency by deploying real workloads to AWS and observing how dispatcher configuration maps to actual vCPU/memory utilization and cost.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Kotlin 1.9 |
| Framework | Ktor 2.3.7 (Netty) |
| Concurrency | kotlinx-coroutines 1.7.3 |
| Metrics | Micrometer + Prometheus |
| Build | Gradle (shadowJar) |
| Container | Docker (Corretto 21) |
| Deploy | AWS Fargate (ECS) + Elastic Beanstalk |
| Viz | Chart.js (server-side HTML, no React/npm) |

## Repository Structure

```
src/main/kotlin/dev/labsji/coroutinelab/
  Application.kt    — Main server, Labs 1-4 (basic concurrency)
  VideoLabs.kt      — Labs 7-10 (video frame processing capstone)
  Dashboard.kt      — Single-instance live results chart
  VizUi.kt          — Side-by-side multi-instance comparison UI
  Proxy.kt          — Server-side proxy for viz (calls backends)

deploy-beanstalk.sh — Deploy to Elastic Beanstalk
deploy-fargate.sh   — Deploy single Fargate task
deploy-multi.sh     — Deploy 3 Fargate configs (256/512/1024 CPU)
teardown-multi.sh   — Cleanup all Fargate resources
create-student.sh   — IAM role setup for student accounts

TUTORIAL.md         — Self-service tutorial (public)
PROGRESS.md         — Student progress tracker (Kiro updates this)
SPEC-viz-ui.md      — Design spec for the viz feature
FargateNotes.md     — Troubleshooting notes for Fargate deployment
```

## Branch Architecture

| Branch | Purpose | Visibility |
|--------|---------|-----------|
| `main` | Public tutorial — self-service content, all code and deploy scripts | Public (GitHub) |
| `tutor-main` | Fresh student state — PROGRESS.md reset, same code as main | Private (CodeCommit) |
| `express-tutor` | Kiro-led flow — AUTOPILOT-SEED.md, EXPRESS-TUTOR-SPEC.md, PinLabs.kt, session notes | Private (CodeCommit) |

## Coding Conventions

- **Package:** `dev.labsji.coroutinelab`
- **Endpoints:** REST, returns JSON for lab results: `{"lab":N,"frames":N,"parallelism":N,"durationMs":N,"fps":N}`
- **No frontend build tools** — viz UI is inline HTML in Kotlin string literals (VizUi.kt)
- **Scripts:** bash, executable, `set -e`, region defaults to `ap-south-1`
- **Documentation:** Markdown, specs use `SPEC-*.md` naming
- **No tests in main** — the app IS the test (run labs, observe metrics)

## AWS Region

Default: `ap-south-1` (Mumbai). All deploy scripts and IAM references use this region.

## Key Design Decisions

1. **Video frames as teaching vehicle** — makes coroutine behavior visceral (not abstract counters)
2. **Server-side proxy** for viz — avoids CORS/mixed-content issues
3. **No npm/webpack** — Chart.js via CDN, keeps build simple
4. **shadowJar** — single fat JAR for Docker, no multi-stage complexity
5. **Multiple Fargate services** (not tasks) — allows side-by-side with different CPU configs
