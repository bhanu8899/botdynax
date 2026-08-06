/**
 * Live-watches the robot's `total_error` fault bitmap and `mop_state` via
 * Tuya's v2.0 thing shadow, so each physical action (remove dust bag,
 * remove mop pad, tip the robot over, ...) can be mapped to the actual
 * fault NUMBER the firmware reports.
 *
 * Per the device's own model: `total_error` is hex, one byte per active
 * fault (`0102041E` = faults 1, 2, 4, 30), `00` = no fault. Tuya delivers
 * it base64-encoded. The number->meaning mapping is not published in any
 * API — it lives in the vendor's panel translations — so it has to be
 * established empirically against the real robot. That is what this does.
 *
 * Run with: npx ts-node scripts/watch-faults.ts
 */
import { readFileSync } from 'fs';
import { join } from 'path';

import axios from 'axios';

import { canonicalizeTuyaPath, signTuyaRequest } from '../src/tuya/tuya-signature.util';

const DEVICE_ID = 'd7ae521a982d49fbc4ikal';
const WATCH_SECONDS = 150;
const POLL_MS = 3000;

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

async function req<T>(path: string, token?: string): Promise<{ success: boolean; result: T }> {
  const headers = signTuyaRequest({ clientId, clientSecret, accessToken: token, method: 'GET', pathWithQuery: path });
  const res = await axios.get<{ success: boolean; result: T }>(`${baseUrl}${canonicalizeTuyaPath(path)}`, {
    headers: headers as unknown as Record<string, string>,
  });
  return res.data;
}

function decodeFaults(base64Value: string): number[] {
  const bytes = Buffer.from(base64Value, 'base64');
  return [...bytes].filter((b) => b !== 0);
}

interface ShadowProperty {
  code: string;
  value: unknown;
}

const WATCHED = ['total_error', 'mop_state', 'status', 'sweep_mop_mode', 'water_output', 'switch_go', 'pause'];

async function main(): Promise<void> {
  const token = (await req<{ access_token: string }>('/v1.0/token?grant_type=1')).result.access_token;

  console.log('Watching total_error / mop_state for ' + WATCH_SECONDS + 's.');
  console.log('Do ONE action at a time and note the order, e.g.:');
  console.log('  1. remove the dust bag      2. put it back');
  console.log('  3. remove the mop pad       4. put it back');
  console.log('  5. remove the water tank    6. put it back\n');

  const previous = new Map<string, string>();
  const faultsSeen = new Set<number>();
  const deadline = Date.now() + WATCH_SECONDS * 1000;
  let first = true;

  while (Date.now() < deadline) {
    try {
      const shadow = await req<{ properties: ShadowProperty[] }>(
        `/v2.0/cloud/thing/${DEVICE_ID}/shadow/properties`,
        token,
      );
      const now = new Date().toISOString().slice(11, 19);

      for (const prop of shadow.result.properties) {
        if (!WATCHED.includes(prop.code)) continue;
        const serialized = JSON.stringify(prop.value);
        if (previous.get(prop.code) === serialized) continue;

        const changed = !first && previous.has(prop.code);
        previous.set(prop.code, serialized);

        if (prop.code === 'total_error') {
          const faults = decodeFaults(String(prop.value));
          faults.forEach((f) => faultsSeen.add(f));
          const label = faults.length ? `FAULTS ACTIVE: [${faults.join(', ')}]` : 'no faults';
          console.log(`${now} ${changed ? '>>> ' : '    '}total_error = ${String(prop.value)}  ->  ${label}`);
        } else if (changed) {
          console.log(`${now} >>> ${prop.code} = ${serialized}`);
        }
      }
      first = false;
    } catch (e) {
      console.log('poll failed:', String(e).slice(0, 100));
    }
    await new Promise((r) => setTimeout(r, POLL_MS));
  }

  console.log(`\nDistinct fault numbers observed: ${[...faultsSeen].sort((a, b) => a - b).join(', ') || '(none)'}`);
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
