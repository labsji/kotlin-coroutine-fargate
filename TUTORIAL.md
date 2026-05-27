# Kotlin Coroutines on AWS — Tutorial

## Labs Overview

| Lab | Coroutine Concept | What You Observe on Real Infra |
|-----|-------------------|-------------------------------|
| 1 | `Dispatchers.Default` (CPU-bound) | Saturates vCPU count, threads = cores |
| 2 | `Dispatchers.IO` (blocking) | 64 threads, memory grows, CPU idle |
| 3 | `limitedParallelism(N)` | Exactly N threads active, rest suspended |
| 4 | `Semaphore(permits)` | Controlled external call rate |
| 5 | Deploy to Beanstalk (vary instance size) | Same code, different resource profiles |
| 6 | Deploy to Fargate (vary CPU units) | Cost optimization via coroutine config |

---

## Lab 1: Dispatchers.Default — CPU Bound

**Concept:** 1000 coroutines ≠ 1000 threads. Default dispatcher uses a thread pool sized to CPU core count.

**Endpoint:** `GET /lab/1`

**Observe at `/metrics`:**
- thread_count = vCPU count (not 1000)
- cpu_utilization = 100%
- memory = flat

---

## Lab 2: Dispatchers.IO — Blocking Work

**Concept:** IO dispatcher allows up to 64 threads for blocking calls. Each thread costs ~1MB.

**Endpoint:** `GET /lab/2`

**Observe:**
- thread_count jumps to 64
- memory grows (~64MB for stacks)
- cpu = low (threads are sleeping)

---

## Lab 3: limitedParallelism — The Throttle

**Concept:** `Dispatchers.Default.limitedParallelism(4)` — only 4 coroutines execute concurrently, 996 suspend.

**Endpoint:** `GET /lab/3?parallelism=4`

**Observe:**
- thread_count = 4 regardless of hardware
- cpu = 4/vCPUs (predictable)
- This is your production knob

---

## Lab 4: Semaphore — Rate Limiting

**Concept:** `Semaphore(10)` limits logical concurrency (e.g., max 10 API calls). Different from limitedParallelism (which limits threads).

**Endpoint:** `GET /lab/4?permits=10`

**Observe:**
- Exactly 10 concurrent external calls
- No thundering herd
- Use when bottleneck is external (API rate limit, DB pool)

---

## Lab 5: Beanstalk — Real Hardware

Deploy same app to different instance sizes:

| Instance | vCPU | Memory | What happens |
|----------|------|--------|-------------|
| t3.micro | 2 | 1GB | Lab 1 saturates. Lab 2 may OOM. |
| t3.small | 2 | 2GB | IO threads fit. CPU still bottleneck. |
| t3.medium | 2 | 4GB | Comfortable for all labs. |

```bash
./deploy-beanstalk.sh t3.small
curl http://<env-url>/lab/1
curl http://<env-url>/metrics
```

### CloudWatch Metrics

Kiro will query CloudWatch via CLI and show you the numbers. To see the visual graphs, open this URL in your browser:

https://ap-south-1.console.aws.amazon.com/cloudwatch/home?region=ap-south-1#metricsV2

Navigate: All Metrics → **AWS/EC2** (not Beanstalk) → Per-Instance Metrics → CPUUtilization

**Important tips for seeing data:**
- Use **EC2 metric**, not Beanstalk metric (Beanstalk's is unreliable)
- Set period to **1 minute** (default 5-min hides short spikes)
- Data appears **2-3 minutes after** load ends (CloudWatch ingestion lag)
- A single curl completes too fast — need **60 seconds of sustained load** to register

### Experiment

To produce a visible graph, run sustained load (Kiro will do this for you):
```bash
# 60s of Lab 1 (full CPU) → pause → 60s of Lab 3 parallelism=1 (throttled)
```

Result on graph: **high spike → drop → low plateau**. Same 1000 coroutines, one config change. That's the visual proof of what `limitedParallelism` does.

Try different configs and watch the graph respond:
- `curl http://<env-url>/lab/1?n=1000` — CPU spikes to 100%
- `curl http://<env-url>/lab/3?parallelism=1` — CPU drops to ~50% on 2-vCPU
- `curl http://<env-url>/lab/3?parallelism=4` — CPU back to 100%
- `curl http://<env-url>/lab/4?permits=5` — steady low CPU

Keep the CloudWatch graph open — refresh every 60s to see the line move with each experiment.

---

## Lab 6: Fargate — Cost Optimization

| CPU Units | vCPU | Memory | Monthly Cost |
|-----------|------|--------|-------------|
| 256 | 0.25 | 512MB | ~$9 |
| 512 | 0.5 | 1GB | ~$18 |
| 1024 | 1 | 2GB | ~$36 |
| 2048 | 2 | 4GB | ~$72 |

**The punchline:** With `limitedParallelism(2)` + `Semaphore(10)`, you handle 1000 concurrent requests on 0.5 vCPU ($18/month). Without coroutine controls: need 2+ vCPU ($72/month). Same throughput, 4x cost difference.

### CloudWatch Metrics (Fargate Container Insights)

Kiro will query CloudWatch via CLI and show you CPU/memory numbers. To see the visual graphs, open this URL in your browser:

https://ap-south-1.console.aws.amazon.com/ecs/v2/clusters/coroutine-lab/services/coroutine-lab-svc/health?region=ap-south-1

### Pre-flight: Fix ecsTaskExecutionRole

Before the service can launch tasks, `ecsTaskExecutionRole` must trust ECS. Run this once as account admin:

```bash
aws iam update-assume-role-policy --role-name ecsTaskExecutionRole --policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "ecs-tasks.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'
```

If tasks show 0 running with no visible error, check events:
```bash
aws ecs describe-services --cluster coroutine-lab --services coroutine-lab-svc \
  --region ap-south-1 --query 'services[0].events[0:3]'
```

### Experiment

Keep the ECS health dashboard open and try different Fargate configs:
- Deploy with 256 CPU → run Lab 1 → watch CPU hit 100%, memory steady
- Deploy with 1024 CPU → run Lab 1 → CPU drops to ~25% (more headroom)
- Deploy with 512 CPU → run Lab 3 with parallelism=1 → CPU barely moves
- Deploy with 256 CPU → run Lab 2 → watch memory spike (64 threads on 512MB)

Each deploy takes ~2 min. The graph updates live — you'll see the shape of your coroutine config reflected in real infrastructure cost.

---

## Student Deliverable

1. CloudWatch screenshots for each lab showing CPU/memory/threads
2. Comparison table: same workload, different configs, different costs
3. Recommendation: "For workload X, optimal config is Y vCPU + limitedParallelism(N) + Semaphore(M) = $Z/month"
