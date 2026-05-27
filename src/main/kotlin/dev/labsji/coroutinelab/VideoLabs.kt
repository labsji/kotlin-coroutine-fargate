package dev.labsji.coroutinelab

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.coroutines.*
import kotlin.math.sqrt

/**
 * Video processing labs (7-10): simulate frame-by-frame processing.
 * Each "frame" is a CPU-bound task (~30ms) representing decode + detect + annotate.
 * No native deps needed — same concurrency behavior as real video processing.
 */
fun Route.videoLabs() {

    // Lab 7: Sequential baseline
    get("/video/lab/7") {
        val frames = call.parameters["frames"]?.toIntOrNull() ?: 100
        val start = System.currentTimeMillis()
        for (i in 0 until frames) { processFrame() }
        val duration = System.currentTimeMillis() - start
        recordResult(7, "sequential", duration, frames)
        call.respondText("""{"lab":7,"frames":$frames,"parallelism":"sequential","durationMs":$duration,"fps":${frames * 1000 / duration}}""", ContentType.Application.Json)
    }

    // Lab 8: Dispatchers.Default (all cores)
    get("/video/lab/8") {
        val frames = call.parameters["frames"]?.toIntOrNull() ?: 100
        val cpus = Runtime.getRuntime().availableProcessors()
        val start = System.currentTimeMillis()
        coroutineScope {
            (0 until frames).map { async(Dispatchers.Default) { processFrame() } }.awaitAll()
        }
        val duration = System.currentTimeMillis() - start
        recordResult(8, "Default($cpus)", duration, frames)
        call.respondText("""{"lab":8,"frames":$frames,"parallelism":"Default($cpus)","durationMs":$duration,"fps":${frames * 1000 / duration}}""", ContentType.Application.Json)
    }

    // Lab 9: limitedParallelism — find the sweet spot
    get("/video/lab/9") {
        val frames = call.parameters["frames"]?.toIntOrNull() ?: 100
        val parallelism = call.parameters["parallelism"]?.toIntOrNull() ?: 4
        val limited = Dispatchers.Default.limitedParallelism(parallelism)
        val start = System.currentTimeMillis()
        coroutineScope {
            (0 until frames).map { async(limited) { processFrame() } }.awaitAll()
        }
        val duration = System.currentTimeMillis() - start
        recordResult(9, "limited($parallelism)", duration, frames)
        call.respondText("""{"lab":9,"frames":$frames,"parallelism":$parallelism,"durationMs":$duration,"fps":${frames * 1000 / duration}}""", ContentType.Application.Json)
    }

    // Lab 10: Same as 9, for comparing across Fargate CPU configs
    get("/video/lab/10") {
        val frames = call.parameters["frames"]?.toIntOrNull() ?: 100
        val parallelism = call.parameters["parallelism"]?.toIntOrNull() ?: 4
        val limited = Dispatchers.Default.limitedParallelism(parallelism)
        val cpus = Runtime.getRuntime().availableProcessors()
        val start = System.currentTimeMillis()
        coroutineScope {
            (0 until frames).map { async(limited) { processFrame() } }.awaitAll()
        }
        val duration = System.currentTimeMillis() - start
        recordResult(10, "limited($parallelism)@${cpus}cpu", duration, frames)
        call.respondText("""{"lab":10,"frames":$frames,"parallelism":$parallelism,"availableProcessors":$cpus,"durationMs":$duration,"fps":${frames * 1000 / duration}}""", ContentType.Application.Json)
    }
}

/**
 * Simulates processing one video frame (~30ms of CPU work).
 * Equivalent to: decode + HSV conversion + circle detection + draw bounding box + encode.
 */
private fun processFrame() {
    // ~30ms of CPU-bound work: compute primes repeatedly
    repeat(50) {
        (2..1000).count { n -> (2..sqrt(n.toDouble()).toInt()).none { n % it == 0 } }
    }
}
