import { Controller, Get, Header } from '@nestjs/common';

/// Serves a self-contained live diagnostics page straight from the API
/// server.
///
/// Deliberately same-origin with the API: it needs no CORS handling, no
/// build step, no install, and works from a phone standing next to the
/// robot. It bootstraps its own guest session, so there is no token to
/// paste in.
///
/// Its reason to exist: the robot's `total_error` fault numbers have no
/// published meaning — the number-to-text mapping lives in the vendor's
/// panel translations, not in any API — so labelling them correctly means
/// triggering a condition on the real machine and reading the number back.
@Controller('diagnostics')
export class DiagnosticsController {
  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  page(): string {
    return PAGE;
  }
}

const PAGE = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>BotDyNax — Robot Live Data</title>
<style>
  :root {
    --bg:#0a0d12; --surface:#12161d; --surface2:#171d26; --border:#232b37;
    --text:#e7ecf2; --muted:#8a96a8; --accent:#45d6c4; --danger:#e2604f; --warn:#e8b04b;
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;
    padding:18px 14px 60px}
  .wrap{max-width:820px;margin:0 auto;display:flex;flex-direction:column;gap:14px}
  h1{margin:0;font-size:19px}
  .sub{color:var(--muted);font-size:12.5px;margin-top:2px}
  .card{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:16px}
  .card h2{margin:0 0 10px;font-size:11.5px;text-transform:uppercase;letter-spacing:.08em;
    color:var(--muted);font-weight:600}
  .fault{border-width:2px}
  .fault.on{border-color:var(--danger)}
  .fault.off{border-color:color-mix(in srgb,var(--accent) 45%,var(--border))}
  .fault-num{font-size:64px;line-height:1;font-weight:800;font-variant-numeric:tabular-nums;
    color:var(--danger);margin:6px 0}
  .ok{font-size:20px;font-weight:700;color:var(--accent);margin:6px 0}
  .raw{font-family:ui-monospace,Consolas,monospace;font-size:11.5px;color:var(--muted)}
  table{width:100%;border-collapse:collapse;font-size:13px}
  td{padding:5px 4px;border-bottom:1px solid var(--border);vertical-align:top}
  td.k{color:var(--muted);font-family:ui-monospace,Consolas,monospace;font-size:12px}
  td.v{text-align:right;font-weight:600;font-family:ui-monospace,Consolas,monospace;font-size:12px;
    word-break:break-all}
  tr.hit td{background:color-mix(in srgb,var(--danger) 16%,transparent)}
  .log{font-family:ui-monospace,Consolas,monospace;font-size:11.5px;max-height:240px;overflow-y:auto}
  .log div{padding:3px 0;border-bottom:1px solid var(--border)}
  .log .t{color:var(--muted)}
  .log .err{color:var(--danger);font-weight:700}
  .pill{display:inline-flex;align-items:center;gap:6px;font-size:12px;padding:4px 10px;
    border-radius:999px;border:1px solid var(--border);background:var(--surface2)}
  .dot{width:7px;height:7px;border-radius:50%;background:var(--muted)}
  .dot.live{background:var(--accent)}
  button{font:inherit;font-size:12.5px;font-weight:600;color:var(--text);background:var(--surface2);
    border:1px solid var(--border);border-radius:9px;padding:8px 12px;cursor:pointer}
  .row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
</style>
</head>
<body>
<div class="wrap">
  <div>
    <div class="row" style="justify-content:space-between">
      <div>
        <h1>Robot Live Data</h1>
        <div class="sub">Every data point the robot reports, updating live.</div>
      </div>
      <span class="pill"><span class="dot" id="dot"></span><span id="conn">connecting…</span></span>
    </div>
  </div>

  <div class="card fault off" id="faultCard">
    <h2>total_error — fault code</h2>
    <div id="faultBody"><div class="ok">connecting…</div></div>
    <div class="raw" id="faultRaw"></div>
  </div>

  <div class="card">
    <h2>Changes (newest first)</h2>
    <div class="log" id="log"><div class="t">waiting…</div></div>
  </div>

  <div class="card">
    <div class="row" style="justify-content:space-between">
      <h2 style="margin:0">All data points <span id="dpCount"></span></h2>
      <button id="copyBtn">Copy all</button>
    </div>
    <table id="dpTable"></table>
  </div>
</div>

<script>
const API = '/api/v1';
const SERIAL = 'd784c044cd0ee1361f329a';
const HILITE = ['total_error','mop_state','status','water_output','sweep_mop_mode'];

let token = null, robotId = null, prev = {}, seeded = false, latest = [];
const logEl = document.getElementById('log');
const logs = [];

function log(msg, isErr) {
  logs.unshift('<div><span class="t">' + new Date().toTimeString().slice(0,8) + '</span> ' +
    (isErr ? '<span class="err">' + msg + '</span>' : msg) + '</div>');
  if (logs.length > 80) logs.pop();
  logEl.innerHTML = logs.join('');
}

async function api(method, path, body) {
  const res = await fetch(API + path, {
    method,
    headers: Object.assign({'Content-Type':'application/json'}, token ? {Authorization:'Bearer '+token} : {}),
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(res.status + ' ' + (await res.text()).slice(0,120));
  return res.status === 204 ? null : res.json();
}

function decodeFaults(b64) {
  if (!b64) return [];
  try {
    const bin = atob(b64);
    const out = [];
    for (let i = 0; i < bin.length; i++) { const c = bin.charCodeAt(i); if (c !== 0) out.push(c); }
    return out;
  } catch (e) { return []; }
}

async function bootstrap() {
  const auth = await api('POST', '/auth/guest');
  token = auth.accessToken;
  const robot = await api('POST', '/robots', {
    serialNumber: SERIAL, name: 'iMap Max W300', model: 'Milagrow iMap Max W300 (LW41MF)',
  });
  robotId = robot.id;
  await api('POST', '/robots/' + robotId + '/tuya-link', { tuyaDeviceId: SERIAL });
  log('connected to robot');
}

function renderFault(points) {
  const map = {};
  points.forEach(p => { map[p.code] = p.value; });
  const raw = map['total_error'];
  const faults = decodeFaults(raw);
  const card = document.getElementById('faultCard');
  const body = document.getElementById('faultBody');

  if (faults.length) {
    card.className = 'card fault on';
    body.innerHTML = '<div class="fault-num">' + faults.join(', ') + '</div>';
  } else {
    card.className = 'card fault off';
    body.innerHTML = '<div class="ok">No faults</div>';
  }
  const hex = faults.map(f => f.toString(16).padStart(2,'0')).join('');
  document.getElementById('faultRaw').textContent =
    'total_error = ' + (raw === undefined ? '—' : JSON.stringify(raw)) + (hex ? '   hex ' + hex : '');
}

function renderTable(points) {
  const rows = points.map(p => {
    const hit = p.code === 'total_error' && decodeFaults(p.value).length;
    return '<tr class="' + (hit ? 'hit' : '') + '"><td class="k">' + p.code +
      '</td><td class="v">' + JSON.stringify(p.value) + '</td></tr>';
  });
  document.getElementById('dpTable').innerHTML = rows.join('');
  document.getElementById('dpCount').textContent = '(' + points.length + ')';
}

function diff(points) {
  points.forEach(p => {
    const v = JSON.stringify(p.value);
    const old = prev[p.code];
    if (old === v) return;
    prev[p.code] = v;
    if (!seeded || old === undefined) return;
    const isErr = p.code === 'total_error';
    let extra = '';
    if (isErr) {
      const f = decodeFaults(p.value);
      extra = f.length ? '  →  FAULT ' + f.join(', ') : '  →  cleared';
    }
    log(p.code + ': ' + old + ' → ' + v + extra, isErr || HILITE.includes(p.code));
  });
  seeded = true;
}

async function poll() {
  try {
    const points = await api('GET', '/tuya/robots/' + robotId + '/status');
    latest = points;
    document.getElementById('dot').className = 'dot live';
    document.getElementById('conn').textContent = 'live';
    diff(points);
    renderFault(points);
    renderTable(points);
  } catch (e) {
    document.getElementById('dot').className = 'dot';
    document.getElementById('conn').textContent = 'error';
    log('poll failed: ' + e.message, true);
  }
}

document.getElementById('copyBtn').addEventListener('click', () => {
  const dump = latest.map(p => p.code + ' = ' + JSON.stringify(p.value)).join('\\n');
  navigator.clipboard.writeText(dump).then(() => log('copied ' + latest.length + ' data points'));
});

bootstrap()
  .then(() => { poll(); setInterval(poll, 2000); })
  .catch(e => { log('setup failed: ' + e.message, true);
    document.getElementById('conn').textContent = 'failed'; });
</script>
</body>
</html>`;
