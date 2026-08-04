/**
 * Pulls the device's raw event/data-report logs from Tuya to discover
 * EVERY DP code the robot has actually reported over time — including any
 * that don't appear in the current `/status` snapshot or the declared
 * `/specifications` schema.
 *
 * Motivation: this robot demonstrably reports `status` values outside its
 * declared enum ("relocation", "washing", "airing", "relocation_recharge"),
 * so the declared schema is not a reliable inventory of what the firmware
 * actually sends. Smart Life surfaces water-tank / consumable alerts, so
 * if such a signal exists at all it should appear here.
 *
 * Run with: npx ts-node scripts/probe-device-logs.ts
 */
import { readFileSync } from 'fs';
import { join } from 'path';

import axios from 'axios';

import { signTuyaRequest } from '../src/tuya/tuya-signature.util';

const DEVICE_ID = 'd784c044cd0ee1361f329a';

function loadDotEnv(): void {
  const content = readFileSync(join(__dirname, '..', '.env'), 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim().replace(/^"(.*)"$/, '$1');
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadDotEnv();

const baseUrl = process.env.TUYA_BASE_URL ?? '';
const clientId = process.env.TUYA_CLIENT_ID ?? '';
const clientSecret = process.env.TUYA_CLIENT_SECRET ?? '';

async function req<T>(path: string, token?: string): Promise<{ success: boolean; msg?: string; result: T }> {
  const headers = signTuyaRequest({ clientId, clientSecret, accessToken: token, method: 'GET', pathWithQuery: path });
  try {
    const res = await axios.get<{ success: boolean; msg?: string; result: T }>(`${baseUrl}${path}`, {
      headers: headers as unknown as Record<string, string>,
    });
    return res.data;
  } catch (e) {
    const err = e as { response?: { data?: { msg?: string } } };
    return { success: false, msg: err.response?.data?.msg ?? 'request failed', result: undefined as T };
  }
}

interface LogEntry {
  code?: string;
  value?: string;
  event_time?: number;
  event_id?: number;
  event_from?: string;
  status?: string;
}

async function main(): Promise<void> {
  const token = (await req<{ access_token: string }>('/v1.0/token?grant_type=1')).result.access_token;

  const end = Date.now();
  const start = end - 7 * 24 * 60 * 60 * 1000;

  const candidates = [
    `/v1.0/devices/${DEVICE_ID}/logs?type=1,2,3,4,5,6,7,8,9,10&start_time=${start}&end_time=${end}&size=100`,
    `/v1.0/iot-03/devices/${DEVICE_ID}/report-logs?start_time=${start}&end_time=${end}&size=100`,
  ];

  const seenCodes = new Map<string, Set<string>>();

  for (const path of candidates) {
    const r = await req<{ logs?: LogEntry[]; list?: LogEntry[] }>(path, token);
    console.log(`\n=== ${path.split('?')[0]} ===`);
    if (!r.success) {
      console.log(`  FAILED: ${r.msg}`);
      continue;
    }
    const logs = r.result.logs ?? r.result.list ?? [];
    console.log(`  entries: ${logs.length}`);

    for (const entry of logs) {
      if (!entry.code) continue;
      if (!seenCodes.has(entry.code)) seenCodes.set(entry.code, new Set());
      if (entry.value !== undefined) seenCodes.get(entry.code)!.add(String(entry.value));
    }

    // Most recent 25 entries, newest first.
    for (const entry of logs.slice(0, 25)) {
      const when = entry.event_time ? new Date(entry.event_time).toISOString() : '?';
      console.log(`  ${when}  ${String(entry.code ?? entry.event_id).padEnd(22)} = ${entry.value ?? entry.status ?? ''}`);
    }
    if (logs.length > 0) break;
  }

  console.log('\n=== ALL DISTINCT DP CODES EVER REPORTED (last 7 days) ===');
  const sorted = [...seenCodes.keys()].sort();
  if (sorted.length === 0) {
    console.log('  (none — logs empty or unavailable)');
  }
  for (const code of sorted) {
    const vals = [...seenCodes.get(code)!].slice(0, 12);
    console.log(`  ${code.padEnd(24)} values: ${vals.join(', ')}`);
  }

  const declared = new Set([
    'power_go', 'pause', 'switch_charge', 'mode', 'status', 'customize_mode_switch',
    'suction', 'break_clean', 'clean_time', 'clean_area', 'edge_brush', 'roll_brush',
    'filter', 'electricity_left', 'volume_set', 'direction_control', 'seek',
  ]);
  const undeclared = sorted.filter((c) => !declared.has(c));
  console.log('\n=== CODES *NOT* IN THE DECLARED SPECIFICATION ===');
  console.log(undeclared.length ? undeclared.join(', ') : '  (none)');
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
