package dev.labsji.coroutinelab

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import java.util.concurrent.ConcurrentLinkedDeque

data class LabResult(val lab: Int, val parallelism: String, val durationMs: Long, val fps: Long, val timestamp: Long = System.currentTimeMillis())

val results = ConcurrentLinkedDeque<LabResult>()

fun recordResult(lab: Int, parallelism: String, durationMs: Long, frames: Int) {
    results.addLast(LabResult(lab, parallelism, durationMs, if (durationMs > 0) frames * 1000L / durationMs else 0))
    while (results.size > 50) results.pollFirst()
}

fun Route.dashboard() {
    get("/dashboard") {
        val rows = results.joinToString(",\n            ") { r ->
            """["Lab ${r.lab} (${r.parallelism})", ${r.durationMs}, ${r.fps}]"""
        }
        call.respondText("""
<!DOCTYPE html>
<html><head><title>Coroutine Lab Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>body{font-family:system-ui;max-width:900px;margin:40px auto;padding:0 20px}h1{color:#333}canvas{margin:20px 0}.stats{display:flex;gap:20px;flex-wrap:wrap}.card{background:#f5f5f5;padding:16px;border-radius:8px;min-width:150px}
.card h3{margin:0;font-size:14px;color:#666}.card p{margin:4px 0 0;font-size:24px;font-weight:bold}</style></head>
<body>
<h1>Kotlin Coroutine Lab — Live Results</h1>
<div class="stats">
  <div class="card"><h3>Available Processors</h3><p>${Runtime.getRuntime().availableProcessors()}</p></div>
  <div class="card"><h3>Results Recorded</h3><p>${results.size}</p></div>
</div>
<canvas id="duration" height="80"></canvas>
<canvas id="fps" height="80"></canvas>
<p style="color:#888">Run labs via curl, then refresh this page. Auto-refreshes every 10s.</p>
<script>
const data = [
            $rows
        ];
const labels = data.map(d => d[0]);
const durations = data.map(d => d[1]);
const fps = data.map(d => d[2]);

new Chart(document.getElementById('duration'), {
    type: 'bar', data: { labels, datasets: [{label:'Duration (ms)',data:durations,backgroundColor:'#e74c3c'}] },
    options: { plugins:{title:{display:true,text:'Processing Duration (lower = better)'}}}
});
new Chart(document.getElementById('fps'), {
    type: 'bar', data: { labels, datasets: [{label:'FPS',data:fps,backgroundColor:'#2ecc71'}] },
    options: { plugins:{title:{display:true,text:'Frames Per Second (higher = better)'}}}
});
setTimeout(() => location.reload(), 10000);
</script>
</body></html>
        """.trimIndent(), ContentType.Text.Html)
    }
}
