package dev.labsji.coroutinelab

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun Route.vizUi() {
    get("/viz") {
        call.respondText(VIZ_HTML, ContentType.Text.Html)
    }
}

private val VIZ_HTML = """
<!DOCTYPE html>
<html><head><title>Coroutine Lab — Side-by-Side</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
body{font-family:system-ui;max-width:1100px;margin:20px auto;padding:0 20px;background:#1a1a2e;color:#eee}
h1{color:#e94560}
.controls{background:#16213e;padding:20px;border-radius:12px;margin:20px 0;display:flex;gap:20px;align-items:center;flex-wrap:wrap}
.controls label{font-size:14px;color:#aaa}
.controls input[type=range]{width:150px}
.controls button{background:#e94560;color:#fff;border:none;padding:10px 24px;border-radius:6px;cursor:pointer;font-size:16px}
.controls button:disabled{background:#555}
.instances{background:#16213e;padding:16px;border-radius:12px;margin:10px 0}
.instance-row{display:flex;align-items:center;gap:12px;padding:6px 0}
.instance-row input[type=text]{background:#0f3460;border:1px solid #333;color:#eee;padding:6px 10px;border-radius:4px;width:180px}
.instance-row .tag{background:#e94560;color:#fff;padding:2px 8px;border-radius:4px;font-size:12px}
canvas{background:#16213e;border-radius:12px;padding:10px;margin:10px 0}
#results-table{width:100%;border-collapse:collapse;margin:20px 0}
#results-table th,#results-table td{padding:8px 12px;text-align:left;border-bottom:1px solid #333}
#results-table th{color:#e94560}
.note{background:#0f3460;padding:12px;border-radius:8px;margin:10px 0;font-size:13px;color:#aaa}
</style></head>
<body>
<h1>⚡ Kotlin Coroutine Lab — Side-by-Side</h1>

<div class="note">
  <strong>How it works:</strong> This page calls backend instances through a server-side proxy (no mixed-content issues).
  Beanstalk instances have burstable CPU (t3 credits). Fargate has fixed CPU. Compare them to see the difference.
</div>

<div class="instances">
  <strong>Backend Instances</strong> (private IPs — proxy handles the calls)<br><br>
  <div class="instance-row"><input type="checkbox" checked class="inst-check" data-idx="0"><input type="text" id="ip0" placeholder="IP (e.g. 172.31.x.x or public)" value=""><span class="tag" id="tag0">Fargate 256</span></div>
  <div class="instance-row"><input type="checkbox" checked class="inst-check" data-idx="1"><input type="text" id="ip1" placeholder="IP" value=""><span class="tag" id="tag1">Fargate 512</span></div>
  <div class="instance-row"><input type="checkbox" checked class="inst-check" data-idx="2"><input type="text" id="ip2" placeholder="IP" value=""><span class="tag" id="tag2">Fargate 1024</span></div>
  <div class="instance-row"><input type="checkbox" class="inst-check" data-idx="3"><input type="text" id="ip3" placeholder="IP (optional)" value=""><span class="tag" id="tag3">Beanstalk</span></div>
</div>

<div class="controls">
  <div><label>Parallelism: <strong id="pval">4</strong></label><br><input type="range" id="parallelism" min="1" max="16" value="4"></div>
  <div><label>Frames: <strong id="fval">100</strong></label><br><input type="range" id="frames" min="10" max="500" step="10" value="100"></div>
  <div><label>Lab:</label><br><select id="lab"><option value="video/lab/9">Video (Lab 9)</option><option value="video/lab/7">Video Sequential</option><option value="video/lab/8">Video Default</option></select></div>
  <button id="run" onclick="runAll()">▶ RUN ALL</button>
</div>

<canvas id="chart-duration" height="70"></canvas>
<canvas id="chart-fps" height="70"></canvas>

<table id="results-table">
  <thead><tr><th>Instance</th><th>Duration (ms)</th><th>FPS</th><th>Parallelism</th><th>Processors</th></tr></thead>
  <tbody id="results-body"></tbody>
</table>

<script>
let durationChart, fpsChart;

// Pre-fill from query params: /viz?i=IP1,IP2,IP3&labels=Fargate256,Fargate512,Fargate1024
const params = new URLSearchParams(window.location.search);
const ips = (params.get('i') || '').split(',').filter(Boolean);
const labels = (params.get('labels') || '').split(',').filter(Boolean);
ips.forEach((ip, idx) => {
  const el = document.getElementById('ip'+idx);
  if (el) el.value = ip;
  if (labels[idx]) { const tag = document.getElementById('tag'+idx); if(tag) tag.textContent = labels[idx]; }
});

document.getElementById('parallelism').oninput = e => document.getElementById('pval').textContent = e.target.value;
document.getElementById('frames').oninput = e => document.getElementById('fval').textContent = e.target.value;

async function runAll() {
  const btn = document.getElementById('run');
  btn.disabled = true; btn.textContent = '⏳ Running...';

  const p = document.getElementById('parallelism').value;
  const f = document.getElementById('frames').value;
  const lab = document.getElementById('lab').value;

  // Collect checked IPs
  const targets = [];
  for (let i = 0; i < 4; i++) {
    const cb = document.querySelectorAll('.inst-check')[i];
    const ip = document.getElementById('ip'+i).value.trim();
    if (cb.checked && ip) targets.push(ip);
  }

  if (targets.length === 0) { btn.disabled = false; btn.textContent = '▶ RUN ALL'; return; }

  // Call proxy (server-side, no CORS issues)
  const url = '/proxy/run?targets=' + targets.join(',') + '&lab=' + lab + '&frames=' + f + '&parallelism=' + p;
  try {
    const resp = await fetch(url);
    const results = await resp.json();
    renderResults(results);
  } catch(e) {
    console.error(e);
  }
  btn.disabled = false; btn.textContent = '▶ RUN ALL';
}

function renderResults(results) {
  const valid = results.filter(r => r.status === 'ok');
  const labels = valid.map(r => r.target);
  const durations = valid.map(r => r.data.durationMs || r.data.totalMs);
  const fps = valid.map(r => r.data.fps || r.data.throughput_per_sec || 0);

  if (durationChart) durationChart.destroy();
  if (fpsChart) fpsChart.destroy();

  durationChart = new Chart(document.getElementById('chart-duration'), {
    type:'bar', data:{labels, datasets:[{label:'Duration (ms)',data:durations,backgroundColor:'#e74c3c'}]},
    options:{plugins:{title:{display:true,text:'Duration (lower = better)',color:'#eee'}},scales:{y:{ticks:{color:'#aaa'}},x:{ticks:{color:'#aaa'}}}}
  });
  fpsChart = new Chart(document.getElementById('chart-fps'), {
    type:'bar', data:{labels, datasets:[{label:'FPS',data:fps,backgroundColor:'#2ecc71'}]},
    options:{plugins:{title:{display:true,text:'Throughput (higher = better)',color:'#eee'}},scales:{y:{ticks:{color:'#aaa'}},x:{ticks:{color:'#aaa'}}}}
  });

  const tbody = document.getElementById('results-body');
  tbody.innerHTML = valid.map(r => {
    const d = r.data;
    return '<tr><td>'+r.target+'</td><td>'+(d.durationMs||d.totalMs)+'</td><td>'+(d.fps||d.throughput_per_sec||'-')+'</td><td>'+(d.parallelism||'-')+'</td><td>'+(d.availableProcessors||'-')+'</td></tr>';
  }).join('');
}
</script>
</body></html>
""".trimIndent()
