/**
 * Exercises the EXACT sequenced command batches TuyaWireProtocol produces
 * for StartCleaningCommand(mode: auto) — mode committed first, then
 * power_go toggled as a second, separate call — directly against the real
 * Milagrow iMap Max W300, bypassing the backend/app entirely so we can
 * observe Tuya's raw response and the device's resulting status.
 *
 * Run with: npx ts-node scripts/test-send-command.ts
 */
import { readFileSync } from 'fs';
import { join } from 'path';

import axios from 'axios';

import { signTuyaRequest } from '../src/tuya/tuya-signature.util';

const DEVICE_ID = 'd784c044cd0ee1361f329a';

function loadDotEnv(): void {
  const envPath = join(__dirname, '..', '.env');
  const content = readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) continue;
    const key = trimmed.slice(0, eqIndex).trim();
    const value = trimmed.slice(eqIndex + 1).trim().replace(/^"(.*)"$/, '$1');
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadDotEnv();

const baseUrl = process.env.TUYA_BASE_URL ?? '';
const clientId = process.env.TUYA_CLIENT_ID ?? '';
const clientSecret = process.env.TUYA_CLIENT_SECRET ?? '';

interface TuyaEnvelope<T> {
  success: boolean;
  code?: number;
  msg?: string;
  result: T;
}

async function signedRequest<T>(
  method: 'GET' | 'POST',
  path: string,
  accessToken?: string,
  body?: unknown,
): Promise<TuyaEnvelope<T>> {
  const bodyString = body !== undefined ? JSON.stringify(body) : undefined;
  const headers = signTuyaRequest({
    clientId,
    clientSecret,
    accessToken,
    method,
    pathWithQuery: path,
    body: bodyString,
  });
  const response = await axios.request<TuyaEnvelope<T>>({
    method,
    url: `${baseUrl}${path}`,
    data: bodyString,
    headers: { ...headers, 'Content-Type': 'application/json' } as unknown as Record<string, string>,
  });
  return response.data;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function printStatus(accessToken: string, label: string): Promise<void> {
  const envelope = await signedRequest<Array<{ code: string; value: unknown }>>(
    'GET',
    `/v1.0/devices/${DEVICE_ID}/status`,
    accessToken,
  );
  console.log(`\n=== ${label} ===`);
  if (!envelope.success) {
    console.log(`❌ ${envelope.code}: ${envelope.msg}`);
    return;
  }
  const relevant = envelope.result.filter((p) =>
    ['power_go', 'pause', 'mode', 'status', 'clean_time', 'clean_area', 'switch_charge'].includes(p.code),
  );
  console.log(JSON.stringify(relevant, null, 2));
}

async function main(): Promise<void> {
  if (!baseUrl || !clientId || !clientSecret) {
    console.error('Missing TUYA_BASE_URL / TUYA_CLIENT_ID / TUYA_CLIENT_SECRET in environment.');
    process.exitCode = 1;
    return;
  }

  const tokenEnvelope = await signedRequest<{ access_token: string }>('GET', '/v1.0/token?grant_type=1');
  if (!tokenEnvelope.success) {
    console.log(`❌ Token fetch failed: ${tokenEnvelope.code}: ${tokenEnvelope.msg}`);
    process.exitCode = 1;
    return;
  }
  const accessToken = tokenEnvelope.result.access_token;
  console.log('✅ Got project access token.');

  await printStatus(accessToken, 'BEFORE');

  console.log('\n=== Sending batch 1: mode = smart ===');
  const modeResult = await signedRequest<{ success: boolean }>(
    'POST',
    `/v1.0/devices/${DEVICE_ID}/commands`,
    accessToken,
    { commands: [{ code: 'mode', value: 'smart' }] },
  );
  console.log(modeResult.success ? '✅ Accepted' : `❌ ${modeResult.code}: ${modeResult.msg}`);

  await sleep(1500);

  console.log('\n=== Sending batch 2: power_go = true ===');
  const powerGoResult = await signedRequest<{ success: boolean }>(
    'POST',
    `/v1.0/devices/${DEVICE_ID}/commands`,
    accessToken,
    { commands: [{ code: 'power_go', value: true }] },
  );
  console.log(powerGoResult.success ? '✅ Accepted' : `❌ ${powerGoResult.code}: ${powerGoResult.msg}`);

  await sleep(3000);
  await printStatus(accessToken, 'AFTER (3s later)');

  await sleep(7000);
  await printStatus(accessToken, 'AFTER (10s later) — watch clean_time/clean_area for movement');
}

main().catch((error: unknown) => {
  if (axios.isAxiosError(error)) {
    console.error('❌ Request failed:', error.response?.status, JSON.stringify(error.response?.data));
  } else {
    console.error('❌ Unexpected error:', error);
  }
  process.exitCode = 1;
});
