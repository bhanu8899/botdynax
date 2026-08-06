/**
 * Pins down the exact `pathData.rawData` format by validating decoded
 * points against the map's own grid. The correct header length + scale is
 * the one where ~all points land inside the grid bounds.
 *
 * Hypothesis under test: raw coords are millimetres in the robot's frame;
 * map cell = raw / (resolution * 10) + origin, where `resolution` is cm.
 *
 * Run with: npx ts-node scripts/validate-path-format.ts
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

async function req<T>(path: string, token?: string): Promise<{ success: boolean; result: T }> {
  const headers = signTuyaRequest({ clientId, clientSecret, accessToken: token, method: 'GET', pathWithQuery: path });
  const res = await axios.get<{ success: boolean; result: T }>(`${baseUrl}${path}`, {
    headers: headers as unknown as Record<string, string>,
  });
  return res.data;
}

async function main(): Promise<void> {
  const tokenRes = await req<{ access_token: string }>('/v1.0/token?grant_type=1');
  const token = tokenRes.result.access_token;

  const list = await req<{ datas: Array<{ id: number; time: number }> }>(
    `/v1.0/users/sweepers/file/${DEVICE_ID}/list?file_type=pic&page_no=1&page_size=20`,
    token,
  );
  const newest = list.result.datas.reduce((a, b) => (b.time > a.time ? b : a));
  const dl = await req<{ app_map: string }>(
    `/v1.0/users/sweepers/file/${DEVICE_ID}/download?id=${newest.id}`,
    token,
  );
  const file = await axios.get<string>(dl.result.app_map, {
    responseType: 'text',
    transformResponse: (d: string) => d,
  });
  const parsed = JSON.parse(file.data) as {
    mapData: {
      size: [number, number];
      origin: [number, number];
      resolution: number;
      charger?: { coordinate: [number, number] };
      obstacles?: Array<{ coordinates: number[] }>;
    };
    pathData: { rawData: string };
  };

  const { size, origin, resolution, charger } = parsed.mapData;
  const [gridW, gridH] = size;
  const bytes = Buffer.from(parsed.pathData.rawData, 'hex');

  const declaredCount = bytes.readUInt16LE(8);
  console.log(`blob=${bytes.length}B  declaredCount(@8)=${declaredCount}  field@10=${bytes.readUInt16LE(10)}`);
  console.log(`grid=${gridW}x${gridH} origin=${origin} resolution=${resolution} charger=${JSON.stringify(charger)}`);
  console.log(`\nheader candidates that yield exactly ${declaredCount} points:`);
  for (let h = 8; h <= 24; h++) {
    const n = Math.floor((bytes.length - h) / 4);
    if (n === declaredCount) console.log(`  headerLen=${h} -> ${n} pts (leftover ${(bytes.length - h) % 4}B)`);
  }

  // Validate scale hypotheses for the best-fitting header lengths.
  for (const headerLen of [16, 17]) {
    const body = bytes.subarray(headerLen);
    const n = Math.floor(body.length / 4);
    const pts: Array<[number, number]> = [];
    for (let i = 0; i < n; i++) pts.push([body.readInt16LE(i * 4), body.readInt16LE(i * 4 + 2)]);

    console.log(`\n=== headerLen=${headerLen} (${n} pts) ===`);
    for (const [label, div] of [
      ['mm  (raw/(res*10))', resolution * 10],
      ['cm  (raw/res)', resolution],
      ['raw (no scale)', 1],
    ] as Array<[string, number]>) {
      let inside = 0;
      const cells = pts.map(([x, y]) => {
        const cx = x / div + origin[0];
        const cy = y / div + origin[1];
        if (cx >= 0 && cx < gridW && cy >= 0 && cy < gridH) inside++;
        return [cx, cy] as [number, number];
      });
      const pct = ((inside / n) * 100).toFixed(1);
      const last = cells[cells.length - 1];
      const chargerDist = charger
        ? Math.hypot(last[0] - charger.coordinate[0], last[1] - charger.coordinate[1]).toFixed(1)
        : 'n/a';
      console.log(
        `  ${label.padEnd(20)} inside=${pct}%  last=(${last[0].toFixed(1)},${last[1].toFixed(1)})  distToCharger=${chargerDist}`,
      );
    }
  }
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
