/**
 * Decodes the `pathData.rawData` hex blob from a Tuya sweeper map file
 * into real (x, y) trajectory coordinates, and sanity-checks them against
 * the map's own grid dimensions/origin.
 *
 * Run with: npx ts-node scripts/decode-path.ts
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

interface Envelope<T> {
  success: boolean;
  msg?: string;
  result: T;
}

async function req<T>(path: string, token?: string): Promise<Envelope<T>> {
  const headers = signTuyaRequest({
    clientId,
    clientSecret,
    accessToken: token,
    method: 'GET',
    pathWithQuery: path,
  });
  const res = await axios.get<Envelope<T>>(`${baseUrl}${path}`, {
    headers: headers as unknown as Record<string, string>,
  });
  return res.data;
}

/// Interprets the blob as: a header, then a sequence of signed 16-bit
/// little-endian (x, y) pairs. Tries several header lengths and reports
/// which one produces coordinates that actually fit the map's grid.
function decodeCandidates(hex: string, gridW: number, gridH: number): void {
  const bytes = Buffer.from(hex, 'hex');
  console.log(`\nblob: ${bytes.length} bytes (${hex.length} hex chars)`);
  console.log(`first 24 bytes: ${bytes.subarray(0, 24).toString('hex').match(/../g)?.join(' ')}`);

  for (const headerLen of [8, 10, 12, 16]) {
    const body = bytes.subarray(headerLen);
    const pointCount = Math.floor(body.length / 4);
    if (pointCount < 2) continue;

    const pts: Array<[number, number]> = [];
    for (let i = 0; i < pointCount; i++) {
      pts.push([body.readInt16LE(i * 4), body.readInt16LE(i * 4 + 2)]);
    }

    const xs = pts.map((p) => p[0]);
    const ys = pts.map((p) => p[1]);
    const minX = Math.min(...xs);
    const maxX = Math.max(...xs);
    const minY = Math.min(...ys);
    const maxY = Math.max(...ys);

    // Consecutive-point distance: a real trajectory moves in small steps.
    let jumps = 0;
    let totalStep = 0;
    for (let i = 1; i < pts.length; i++) {
      const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      totalStep += d;
      if (d > 200) jumps++;
    }
    const avgStep = totalStep / Math.max(1, pts.length - 1);

    console.log(
      `\n  headerLen=${headerLen}: ${pointCount} pts  ` +
        `x[${minX}..${maxX}] y[${minY}..${maxY}]  avgStep=${avgStep.toFixed(1)}  bigJumps=${jumps}`,
    );
    console.log(`    first 6: ${pts.slice(0, 6).map((p) => `(${p[0]},${p[1]})`).join(' ')}`);
    console.log(`    last 6:  ${pts.slice(-6).map((p) => `(${p[0]},${p[1]})`).join(' ')}`);
    console.log(`    (map grid is ${gridW} x ${gridH})`);
  }
}

async function main(): Promise<void> {
  const tokenRes = await req<{ access_token: string }>('/v1.0/token?grant_type=1');
  const token = tokenRes.result.access_token;

  const list = await req<{ datas: Array<{ id: number; time: number }> }>(
    `/v1.0/users/sweepers/file/${DEVICE_ID}/list?file_type=pic&page_no=1&page_size=20`,
    token,
  );
  const newest = list.result.datas.reduce((a, b) => (b.time > a.time ? b : a));
  console.log(`newest map file id=${newest.id} time=${new Date(newest.time * 1000).toISOString()}`);

  const dl = await req<{ app_map: string }>(
    `/v1.0/users/sweepers/file/${DEVICE_ID}/download?id=${newest.id}`,
    token,
  );
  const file = await axios.get<string>(dl.result.app_map, {
    responseType: 'text',
    transformResponse: (d: string) => d,
  });
  const parsed = JSON.parse(file.data) as {
    mapData: { size: [number, number]; origin: [number, number]; resolution: number; charger?: { coordinate: [number, number] } };
    pathData: { rawData: string };
  };

  const { size, origin, resolution, charger } = parsed.mapData;
  console.log(`map: size=${size} origin=${origin} resolution=${resolution} charger=${JSON.stringify(charger)}`);

  decodeCandidates(parsed.pathData.rawData, size[0], size[1]);
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
