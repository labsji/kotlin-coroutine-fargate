package dev.labsji.coroutinelab

import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.metrics.micrometer.*
import io.micrometer.prometheusmetrics.PrometheusConfig
import io.micrometer.prometheusmetrics.PrometheusMeterRegistry
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.sqrt

fun main() {
    embeddedServer(Netty, port = 8080, module = Application::module).start(wait = true)
}

fun Application.module() {
    val prometheus = PrometheusMeterRegistry(PrometheusConfig.DEFAULT)
    install(MicrometerMetrics) { registry = prometheus }
    install(io.ktor.server.plugins.cors.routing.CORS) { anyHost() }

    routing {
        // Lab 1: CPU-bound on Dispatchers.Default
        get("/lab/1") {
            val count = call.parameters["n"]?.toIntOrNull() ?: 1000
            val active = AtomicInteger(0)
            val peak = AtomicInteger(0)
            coroutineScope {
                repeat(count) {
                    launch(Dispatchers.Default) {
                        val cur = active.incrementAndGet()
                        peak.updateAndGet { max -> maxOf(max, cur) }
                        cpuWork()
                        active.decrementAndGet()
                    }
                }
            }
            call.respondText("Lab 1: $count coroutines on Default. Peak concurrent: ${peak.get()}")
        }

        // Lab 2: IO-bound on Dispatchers.IO
        get("/lab/2") {
            val count = call.parameters["n"]?.toIntOrNull() ?: 1000
            val active = AtomicInteger(0)
            val peak = AtomicInteger(0)
            coroutineScope {
                repeat(count) {
                    launch(Dispatchers.IO) {
                        val cur = active.incrementAndGet()
                        peak.updateAndGet { max -> maxOf(max, cur) }
                        Thread.sleep(100) // simulate blocking IO
                        active.decrementAndGet()
                    }
                }
            }
            call.respondText("Lab 2: $count coroutines on IO. Peak concurrent: ${peak.get()}")
        }

        // Lab 3: limitedParallelism
        get("/lab/3") {
            val count = call.parameters["n"]?.toIntOrNull() ?: 1000
            val parallelism = call.parameters["parallelism"]?.toIntOrNull() ?: 4
            val limited = Dispatchers.Default.limitedParallelism(parallelism)
            val active = AtomicInteger(0)
            val peak = AtomicInteger(0)
            coroutineScope {
                repeat(count) {
                    launch(limited) {
                        val cur = active.incrementAndGet()
                        peak.updateAndGet { max -> maxOf(max, cur) }
                        cpuWork()
                        active.decrementAndGet()
                    }
                }
            }
            call.respondText("Lab 3: $count coroutines, limitedParallelism($parallelism). Peak concurrent: ${peak.get()}")
        }

        // Lab 4: Semaphore
        get("/lab/4") {
            val count = call.parameters["n"]?.toIntOrNull() ?: 1000
            val permits = call.parameters["permits"]?.toIntOrNull() ?: 10
            val semaphore = Semaphore(permits)
            val active = AtomicInteger(0)
            val peak = AtomicInteger(0)
            coroutineScope {
                repeat(count) {
                    launch {
                        semaphore.withPermit {
                            val cur = active.incrementAndGet()
                            peak.updateAndGet { max -> maxOf(max, cur) }
                            delay(100) // simulate async IO
                            active.decrementAndGet()
                        }
                    }
                }
            }
            call.respondText("Lab 4: $count coroutines, Semaphore($permits). Peak concurrent: ${peak.get()}")
        }

        // Metrics endpoint
        get("/metrics") {
            val threads = Thread.activeCount()
            val runtime = Runtime.getRuntime()
            val usedMem = (runtime.totalMemory() - runtime.freeMemory()) / 1024 / 1024
            val maxMem = runtime.maxMemory() / 1024 / 1024
            val cpus = runtime.availableProcessors()
            call.respondText(
                """
                |# Runtime Metrics
                |threads_active $threads
                |memory_used_mb $usedMem
                |memory_max_mb $maxMem
                |available_processors $cpus
                |
                |${prometheus.scrape()}
                """.trimMargin()
            )
        }

        get("/") {
            call.respondText("""
                |Kotlin Coroutine Lab
                |====================
                |GET /lab/1?n=1000                        — Dispatchers.Default (CPU-bound)
                |GET /lab/2?n=1000                        — Dispatchers.IO (blocking)
                |GET /lab/3?n=1000&parallelism=4          — limitedParallelism
                |GET /lab/4?n=1000&permits=10             — Semaphore
                |GET /video/lab/7?frames=100              — Video: sequential baseline
                |GET /video/lab/8?frames=100              — Video: Dispatchers.Default
                |GET /video/lab/9?frames=100&parallelism=4 — Video: limitedParallelism (U-curve)
                |GET /video/lab/10?frames=100&parallelism=4 — Video: scale hardware test
                |GET /dashboard                              — Live results chart
                |GET /viz                                    — Side-by-side comparison UI
                |GET /metrics                             — Thread count, memory, CPU
            """.trimMargin())
        }

        // Video processing labs (capstone)
        videoLabs()

        // Live dashboard (single instance)
        dashboard()

        // Side-by-side visualization UI
        vizUi()
    }
}

// CPU-bound work: find primes up to 10000
private fun cpuWork() {
    (2..10000).count { n -> (2..sqrt(n.toDouble()).toInt()).none { n % it == 0 } }
}
