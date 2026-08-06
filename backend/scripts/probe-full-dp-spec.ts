/**
 * Discovers the device's FULL data-point specification — including
 * read-only status DPs that never appear in `/functions` (which lists
 * only writable/controllable DPs).
 *
 * This matters because sensor-style signals (water tank removed, dust bin
 * full, mop attached, fault codes) are read-only by nature, so their
 * absence from `/functions` says nothing about whether they exist.
 *
 * Also reports map-snapshot cadence, to explain why the rendered robot
 * position may look frozen.
 *
 * Run with: npx ts-node scripts/probe-full-dp-spec.ts
 */
import { readFileSync } from 'fs';
import { join } from 'path';

import axios from 'axios';

import { signTuyaRequest } from '../src/tuya/tuya-signature.util';

const DEVICE_ID = 'd7ae521a982d49fbc4ikal';

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

async function main(): Promise<void> {
  const token = (await req<{ access_token: string }>('/v1.0/token?grant_type=1')).result.access_token;

  console.log('=== FULL DP SPECIFICATION (functions + read-only status) ===');
  const specPaths = [
    `/v1.1/devices/${DEVICE_ID}/specifications`,
    `/v1.0/devices/${DEVICE_ID}/specifications`,
    `/v1.2/devices/${DEVICE_ID}/specifications`,
    `/v1.0/iot-03/devices/${DEVICE_ID}/specification`,
  ];

  for (const p of specPaths) {
    const r = await req<{ category?: string; functions?: unknown[]; status?: unknown[] }>(p, token);
    if (!r.success) {
      console.log(`  ${p}\n    -> FAILED: ${r.msg}`);
      continue;
    }
    console.log(`  ${p}\n    -> SUCCESS  category=${r.result.category}`);
    console.log(`    functions (writable): ${r.result.functions?.length ?? 0}`);
    console.log(`    status   (readable): ${r.result.status?.length ?? 0}`);
    console.log('\n    --- WRITABLE ---');
    for (const f of (r.result.functions ?? []) as Array<{ code: string; type: string; values: string }>) {
      console.log(`      ${f.code.padEnd(24)} ${f.type.padEnd(8)} ${f.values}`);
    }
    console.log('\n    --- READABLE (incl. sensors) ---');
    for (const s of (r.result.status ?? []) as Array<{ code: string; type: string; values: string }>) {
      console.log(`      ${s.code.padEnd(24)} ${s.type.padEnd(8)} ${s.values}`);
    }
    break;
  }

  console.log('\n=== CURRENT STATUS VALUES ===');
  const st = await req<Array<{ code: string; value: unknown }>>(`/v1.0/devices/${DEVICE_ID}/status`, token);
  for (const p of st.result ?? []) console.log(`  ${p.code.padEnd(24)} = ${JSON.stringify(p.value)}`);

  console.log('\n=== MAP SNAPSHOT CADENCE ===');
  const list = await req<{ datas: Array<{ id: number; time: number }> }>(
    `/v1.0/users/sweepers/file/${DEVICE_ID}/list?file_type=pic&page_no=1&page_size=20`,
    token,
  );
  const sorted = (list.result?.datas ?? []).sort((a, b) => b.time - a.time);
  const now = Math.floor(Date.now() / 1000);
  console.log(`  now = ${new Date(now * 1000).toISOString()}`);
  sorted.slice(0, 10).forEach((d, i) => {
    const ageMin = ((now - d.time) / 60).toFixed(1);
    const gap = i < sorted.length - 1 ? ((d.time - sorted[i + 1].time) / 60).toFixed(1) : 'n/a';
    console.log(`  id=${d.id} ${new Date(d.time * 1000).toISOString()}  age=${ageMin}min  gapToPrev=${gap}min`);
  });
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
