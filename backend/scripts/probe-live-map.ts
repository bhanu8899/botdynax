/**
 * Probes whether live position/path data is obtainable for the Milagrow
 * W300 during an ACTIVE cleaning run — the question `realtime-map` alone
 * did not answer (it returns an empty result even mid-clean).
 *
 * Tests three things the earlier probes missed:
 *  1. Does the map-file LIST grow / does the newest file change while the
 *     robot is actively cleaning? (i.e. are snapshots generated live?)
 *  2. Does the downloaded map file's `pathData.rawData` grow between
 *     polls? That blob is the robot's traveled trajectory.
 *  3. Do other `file_type` values exist beyond `pic`?
 *
 * Run with: npx ts-node scripts/probe-live-map.ts
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
  code?: number;
  msg?: string;
  result: T;
}

async function req<T>(method: 'GET' | 'POST', path: string, token?: string, body?: unknown): Promise<Envelope<T>> {
  const bodyString = body !== undefined ? JSON.stringify(body) : undefined;
  const headers = signTuyaRequest({
    clientId,
    clientSecret,
    accessToken: token,
    method,
    pathWithQuery: path,
    body: bodyString,
  });
  try {
    const res = await axios.request<Envelope<T>>({
      method,
      url: `${baseUrl}${path}`,
      data: bodyString,
      headers: { ...headers, 'Content-Type': 'application/json' } as unknown as Record<string, string>,
    });
    return res.data;
  } catch (e) {
    const err = e as { response?: { data?: unknown } };
    return { success: false, msg: JSON.stringify(err.response?.data), result: undefined as T };
  }
}

interface MapFileEntry {
  id: number;
  time: number;
  extend?: string;
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

async function main(): Promise<void> {
  const tokenRes = await req<{ access_token: string }>('GET', '/v1.0/token?grant_type=1');
  const token = tokenRes.result.access_token;
  console.log('token ok\n');

  // --- Test 3 first (cheap): what file_types exist? ---
  console.log('=== file_type probe ===');
  for (const ft of ['pic', 'path', 'map', 'route', 'realtime', 'trace', 'data']) {
    const r = await req<{ datas: MapFileEntry[] }>(
      'GET',
      `/v1.0/users/sweepers/file/${DEVICE_ID}/list?file_type=${ft}&page_no=1&page_size=5`,
      token,
    );
    const count = r.success && r.result?.datas ? r.result.datas.length : -1;
    console.log(`  file_type=${ft.padEnd(9)} success=${r.success} count=${count}${r.success ? '' : ' msg=' + r.msg}`);
  }

  // --- Tests 1 & 2: watch list + pathData during active cleaning ---
  console.log('\n=== live polling (list + pathData growth) ===');
  let prevTopId: number | undefined;
  let prevPathLen: number | undefined;

  for (let i = 0; i < 10; i++) {
    const statusRes = await req<Array<{ code: string; value: unknown }>>(
      'GET',
      `/v1.0/devices/${DEVICE_ID}/status`,
      token,
    );
    const dp = Object.fromEntries((statusRes.result ?? []).map((p) => [p.code, p.value]));

    const list = await req<{ datas: MapFileEntry[] }>(
      'GET',
      `/v1.0/users/sweepers/file/${DEVICE_ID}/list?file_type=pic&page_no=1&page_size=5`,
      token,
    );
    const datas = list.result?.datas ?? [];
    const newest = datas.length > 0 ? datas.reduce((a, b) => (b.time > a.time ? b : a)) : undefined;

    let pathInfo = 'n/a';
    let robotPos = 'n/a';
    if (newest) {
      const dl = await req<{ app_map: string }>(
        'GET',
        `/v1.0/users/sweepers/file/${DEVICE_ID}/download?id=${newest.id}`,
        token,
      );
      if (dl.success && dl.result?.app_map) {
        try {
          const file = await axios.get<string>(dl.result.app_map, {
            responseType: 'text',
            transformResponse: (d: string) => d,
          });
          const parsed = JSON.parse(file.data) as {
            pathData?: { rawData?: string };
            mapData?: { id?: number };
          };
          const raw = parsed.pathData?.rawData ?? '';
          pathInfo = `len=${raw.length} (${raw.length !== prevPathLen ? 'CHANGED' : 'same'}) mapId=${parsed.mapData?.id}`;
          prevPathLen = raw.length;
          // Last few points of the trajectory blob = most recent position.
          robotPos = raw.length >= 16 ? `...${raw.slice(-16)}` : raw;
        } catch (e) {
          pathInfo = `download/parse failed: ${String(e).slice(0, 60)}`;
        }
      }
    }

    console.log(
      `\n[poll ${i + 1}] status=${String(dp.status)} power_go=${String(dp.power_go)} ` +
        `clean_time=${String(dp.clean_time)} clean_area=${String(dp.clean_area)}`,
    );
    console.log(
      `  files=${datas.length} newestId=${newest?.id}${newest?.id !== prevTopId ? ' <-- NEW FILE' : ''} ` +
        `newestTime=${newest ? new Date(newest.time * 1000).toISOString() : 'n/a'}`,
    );
    console.log(`  pathData: ${pathInfo}`);
    console.log(`  path tail: ${robotPos}`);
    prevTopId = newest?.id;

    await sleep(10000);
  }
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
