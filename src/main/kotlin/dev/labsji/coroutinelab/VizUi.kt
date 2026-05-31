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
.instances input{margin-right:8px}
.instance-row{display:flex;align-items:center;gap:12px;padding:4px 0}
.instance-row .status{width:10px;height:10px;border-radius:50%;background:#555}
.instance-row .status.ok{background:#2ecc71}
.instance-row .status.err{background:#e74c3c}
canvas{background:#16213e;border-radius:12px;padding:10px;margin:10px 0}
#results-table{width:100%;border-collapse:collapse;margin:20px 0}
#results-table th,#results-table td{padding:8px 12px;text-align:left;border-bottom:1px solid #333}
#results-table th{color:#e94560}
.cost{color:#2ecc71;font-weight:bold}
</style></head>
<body>
<h1>⚡ Kotlin Coroutine Lab — Side-by-Side Comparison</h1>

<div class="instances" id="instances">
  <strong>Instances:</strong> <em>Enter instance URLs below (from deploy-multi.sh output)</em><br><br>
  <div class="instance-row"><input type="checkbox" checked class="inst-check" data-idx="0"><input type="text" id="url0" placeholder="http://IP:8080" style="width:200px" value=""><span class="status" id="st0"></span><span id="lbl0">Instance 1</span></div>
  <div class="instance-row"><input type="checkbox" checked class="inst-check" data-idx="1"><input type="text" id="url1" placeholder="http://IP:8080" style="width:200px" value=""><span class="status" id="st1"></span><span id="lbl1">Instance 2</span></div>
  <div class="instance-row"><input type="checkbox" checked class="inst-check" data-idx="2"><input type="text" id="url2" placeholder="http://IP:8080" style="width:200px" value=""><span class="status" id="st2"></span><span id="lbl2">Instance 3</span></div>
  <div class="instance-row"><input type="checkbox" class="inst-check" data-idx="3"><input type="text" id="url3" placeholder="http://IP:8080 (optional)" style="width:200px" value=""><span class="status" id="st3"></span><span id="lbl3">Instance 4</span></div>
</div>

<div class="controls">
  <div><label>Parallelism: <strong id="pval">4</strong></label><br><input type="range" id="parallelism" min="1" max="16" value="4"></div>
  <div><label>Frames: <strong id="fval">100</strong></label><br><input type="range" id="frames" min="10" max="500" step="10" value="100"></div>
  <div><label>Lab:</label><br><select id="lab"><option value="video/lab/9">Video (Lab 9)</option><option value="pin/lab/5">PIN (Lab 5)</option></select></div>
  <button id="run" onclick="runAll()">▶ RUN ALL</button>
</div>

<canvas id="chart-duration" height="60"></canvas>
<canvas id="chart-fps" height="60"></canvas>

<table id="results-table">
  <thead><tr><th>Instance</th><th>Duration (ms)</th><th>FPS / Throughput</th><th>p99 (ms)</th><th>$/hour</th><th>$/1000 frames</th></tr></thead>
  <tbody id="results-body"></tbody>
</table>

<p style="color:#666;font-size:12px">Results update after each run. Instances are hit in parallel. Auto-refreshes disabled — click RUN to compare.</p>

<script>
const costs = {'256':0.012,'512':0.025,'1024':0.049,'2048':0.099,'t3.small':0.021,'t3.micro':0.010};
let durationChart, fpsChart;

document.getElementById('parallelism').oninput = e => document.getElementById('pval').textContent = e.target.value;
document.getElementById('frames').oninput = e => document.getElementById('fval').textContent = e.target.value;

async function runAll() {
  const btn = document.getElementById('run');
  btn.disabled = true; btn.textContent = '⏳ Running...';
  const p = document.getElementById('parallelism').value;
  const f = document.getElementById('frames').value;
  const lab = document.getElementById('lab').value;
  const paramKey = lab.includes('pin') ? 'concurrent' : 'frames';

  const instances = [];
  for (let i = 0; i < 4; i++) {
    const cb = document.querySelectorAll('.inst-check')[i];
    const url = document.getElementById('url'+i).value.trim().replace(/\/$/,'');
    if (cb.checked && url) instances.push({idx:i, url});
  }

  const results = await Promise.all(instances.map(async inst => {
    try {
      const r = await fetch(inst.url + '/' + lab + '?' + paramKey + '=' + f + '&parallelism=' + p);
      const data = await r.json();
      document.getElementById('st'+inst.idx).className = 'status ok';
      return {...data, idx: inst.idx, url: inst.url};
    } catch(e) {
      document.getElementById('st'+inst.idx).className = 'status err';
      return {idx: inst.idx, error: true};
    }
  }));

  renderResults(results, f);
  btn.disabled = false; btn.textContent = '▶ RUN ALL';
}

function renderResults(results, frames) {
  const valid = results.filter(r => !r.error);
  const labels = valid.map(r => document.getElementById('url'+r.idx).value.split(':8080')[0].split('//')[1] || 'Instance '+(r.idx+1));
  const durations = valid.map(r => r.durationMs || r.totalMs);
  const fps = valid.map(r => r.fps || r.throughput_per_sec || 0);

  if (durationChart) durationChart.destroy();
  if (fpsChart) fpsChart.destroy();

  durationChart = new Chart(document.getElementById('chart-duration'), {
    type:'bar', data:{labels, datasets:[{label:'Duration (ms)',data:durations,backgroundColor:'#e74c3c'}]},
    options:{plugins:{title:{display:true,text:'Duration (lower = better)',color:'#eee'}},scales:{y:{ticks:{color:'#aaa'}},x:{ticks:{color:'#aaa'}}}}
  });
  fpsChart = new Chart(document.getElementById('chart-fps'), {
    type:'bar', data:{labels, datasets:[{label:'FPS / Throughput',data:fps,backgroundColor:'#2ecc71'}]},
    options:{plugins:{title:{display:true,text:'Throughput (higher = better)',color:'#eee'}},scales:{y:{ticks:{color:'#aaa'}},x:{ticks:{color:'#aaa'}}}}
  });

  const tbody = document.getElementById('results-body');
  tbody.innerHTML = valid.map(r => {
    const dur = r.durationMs || r.totalMs;
    const t = r.fps || r.throughput_per_sec || 0;
    const p99 = r.p99_ms !== undefined ? r.p99_ms : '-';
    const costHr = 0.05; // placeholder
    const costPer1k = dur > 0 ? (costHr / 3600 * dur * 1000 / frames).toFixed(4) : '-';
    return '<tr><td>'+labels[valid.indexOf(r)]+'</td><td>'+dur+'</td><td>'+t+'</td><td>'+p99+'</td><td class="cost">~$'+costHr.toFixed(3)+'</td><td class="cost">$'+costPer1k+'</td></tr>';
  }).join('');
}
</script>
</body></html>
""".trimIndent()
