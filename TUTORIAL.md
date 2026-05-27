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

---

## Lab 6: Fargate — Cost Optimization

| CPU Units | vCPU | Memory | Monthly Cost |
|-----------|------|--------|-------------|
| 256 | 0.25 | 512MB | ~$9 |
| 512 | 0.5 | 1GB | ~$18 |
| 1024 | 1 | 2GB | ~$36 |
| 2048 | 2 | 4GB | ~$72 |

**The punchline:** With `limitedParallelism(2)` + `Semaphore(10)`, you handle 1000 concurrent requests on 0.5 vCPU ($18/month). Without coroutine controls: need 2+ vCPU ($72/month). Same throughput, 4x cost difference.

---

## Student Deliverable

1. CloudWatch screenshots for each lab showing CPU/memory/threads
2. Comparison table: same workload, different configs, different costs
3. Recommendation: "For workload X, optimal config is Y vCPU + limitedParallelism(N) + Semaphore(M) = $Z/month"
