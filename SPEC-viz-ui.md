# Spec: Side-by-Side Visualization UI

## Concept

Instead of running labs sequentially on one instance, deploy **multiple configs in parallel** and show results side-by-side in a single UI. Student plays with combinations, sees the contrast instantly.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Visualization Instance (t3.small, always-on during lab)     │
│  ─────────────────────────────────────────────────────────── │
│  Static HTML + Chart.js                                      │
│  Polls all target instances, renders side-by-side            │
│  URL: http://<viz-ip>:3000                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ polls /metrics and /video/lab/9 from each
                       ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Fargate   │  │ Fargate   │  │ Fargate   │  │ Beanstalk│
│ 256 CPU   │  │ 512 CPU   │  │ 1024 CPU  │  │ t3.small │
│ 0.25 vCPU │  │ 0.5 vCPU  │  │ 1 vCPU    │  │ 2 vCPU   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

## The UI

Single page with:
- **Config selector:** checkboxes for which instances to compare
- **Parallelism slider:** 1–16 (applies to all instances simultaneously)
- **Frames slider:** 10–500
- **Run button:** fires `/video/lab/9?frames=N&parallelism=P` to all selected instances in parallel
- **Results panel:** side-by-side bar charts (duration, fps, p99 latency)
- **Cost column:** shows $/hour for each config

```
┌─────────────────────────────────────────────────────────────┐
│  Kotlin Coroutine Lab — Side-by-Side Comparison              │
├─────────────────────────────────────────────────────────────┤
│  Parallelism: [====4====]   Frames: [===100===]   [▶ RUN]   │
├─────────────────────────────────────────────────────────────┤
│  ☑ Fargate 256 (0.25 vCPU)  │  Duration: 1200ms  │ $0.012/h│
│  ☑ Fargate 512 (0.5 vCPU)   │  Duration: 620ms   │ $0.025/h│
│  ☑ Fargate 1024 (1 vCPU)    │  Duration: 340ms   │ $0.049/h│
│  ☐ Fargate 2048 (2 vCPU)    │  —                  │ $0.099/h│
│  ☑ Beanstalk t3.small        │  Duration: 310ms   │ $0.021/h│
├─────────────────────────────────────────────────────────────┤
│  [BAR CHART: duration comparison]                            │
│  [BAR CHART: cost-per-frame comparison]                      │
│  [LINE CHART: parallelism sweep — all configs overlaid]      │
└─────────────────────────────────────────────────────────────┘
```

## Workflow

### 1. Spin up (Kiro does this, ~5 min)

```bash
# Deploy app to multiple Fargate configs in parallel
./deploy-multi.sh
```

This script:
- Builds JAR once
- Pushes to ECR once
- Creates 3-4 Fargate tasks with different CPU/memory configs
- Optionally creates a Beanstalk env
- Deploys the viz UI to a separate small instance
- Prints the viz URL

### 2. Student plays (~15-30 min)

- Opens viz URL in browser
- Adjusts parallelism slider, clicks Run
- Watches bars update side-by-side
- Tries: "What happens if parallelism=1 on all configs?" → all slow
- Tries: "What happens if parallelism=4 on 0.25 vCPU?" → bottlenecked by hardware
- Tries: "What's the cheapest config that handles 100 frames in <500ms?"

### 3. Teardown (Kiro does this automatically)

```bash
./teardown-multi.sh
```

Or: auto-teardown after 30 minutes via a scheduled task / CloudWatch alarm.

## deploy-multi.sh

```bash
#!/bin/bash
# Deploys coroutine-lab to multiple Fargate configs + viz UI
CONFIGS=("256:512" "512:1024" "1024:2048")  # CPU:Memory pairs
# ... build, push ECR, create tasks, collect IPs
# ... deploy viz UI with instance IPs baked in
```

## viz UI (static HTML)

Single `index.html` served by a lightweight container (nginx or the app itself on a separate port):
- Fetches from multiple backend IPs
- Chart.js for visualization
- No server-side logic — pure client-side JS polling

## Auto-Teardown

Option A: Kiro reminds student and runs `./teardown-multi.sh` at end of session.

Option B: Lambda scheduled 30 min after deploy:
```bash
aws scheduler create-schedule --name teardown-coroutine-lab \
  --schedule-expression "at($(date -u -d '+30 min' +%Y-%m-%dT%H:%M:%S))" \
  --target '{"Arn":"arn:aws:lambda:...","Input":"{\"action\":\"teardown\"}"}'
```

Option C: Tag all resources with `ttl=30m`, a cleanup Lambda runs every 5 min and deletes expired resources.

**Recommendation:** Option A for MVP (Kiro handles it). Option C for production.

## Cost for a 30-min Session

| Resource | Cost |
|----------|------|
| 3 Fargate tasks (256+512+1024) × 30 min | ~$0.04 |
| 1 Beanstalk t3.small × 30 min | ~$0.01 |
| 1 Viz instance (t3.micro) × 30 min | ~$0.005 |
| ECR storage | ~$0.01 |
| **Total per student session** | **~$0.07** |

## Student Deliverable

Screenshot of the viz UI showing:
1. Side-by-side bars proving `parallelism = vCPU` is optimal per config
2. Cost-per-frame calculation showing the sweet spot
3. The "aha" moment: 0.5 vCPU + parallelism=1 costs less AND performs adequately for low-throughput workloads
