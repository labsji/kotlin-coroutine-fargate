package dev.labsji.coroutinelab

import io.ktor.client.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope

/**
 * Proxy endpoint: viz instance calls backend instances server-side.
 * Browser never talks to backends directly — no mixed content, no CORS issues.
 */
private val client = HttpClient()

fun Route.proxyEndpoint() {

    // Run a lab on multiple backends in parallel, return combined results
    // GET /proxy/run?targets=IP1,IP2,IP3&lab=video/lab/9&frames=100&parallelism=4
    get("/proxy/run") {
        val targets = call.parameters["targets"]?.split(",")?.filter { it.isNotBlank() } ?: emptyList()
        val lab = call.parameters["lab"] ?: "video/lab/9"
        val frames = call.parameters["frames"] ?: "100"
        val parallelism = call.parameters["parallelism"] ?: "4"
        val concurrent = call.parameters["concurrent"] ?: "100"

        if (targets.isEmpty()) {
            call.respondText("""{"error":"no targets specified"}""", ContentType.Application.Json)
            return@get
        }

        val paramKey = if (lab.contains("pin")) "concurrent" else "frames"
        val paramVal = if (lab.contains("pin")) concurrent else frames

        val results = coroutineScope {
            targets.map { target ->
                async {
                    try {
                        val url = "http://${target}:8080/${lab}?${paramKey}=${paramVal}&parallelism=${parallelism}"
                        val resp = client.get(url)
                        """{"target":"$target","status":"ok","data":${resp.bodyAsText()}}"""
                    } catch (e: Exception) {
                        """{"target":"$target","status":"error","error":"${e.message?.take(100)}"}"""
                    }
                }
            }.awaitAll()
        }

        call.respondText("[${results.joinToString(",")}]", ContentType.Application.Json)
    }
}
