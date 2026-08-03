/**
 * One-off connectivity check:
 *  1. Confirms TUYA_CLIENT_ID/TUYA_CLIENT_SECRET/TUYA_BASE_URL are correct
 *     by fetching a project-level access token (grant_type=1).
 *  2. Uses that token to query the real Milagrow iMap Max W300
 *     (device_id below) directly — device info, status, and functions —
 *     to confirm the device is reachable from this Tuya Cloud project
 *     and to discover its real DP schema.
 *
 * Run with: npx ts-node scripts/test-tuya-connection.ts
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
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

loadDotEnv();

const baseUrl = process.env.TUYA_BASE_URL ?? '';
const clientId = process.env.TUYA_CLIENT_ID ?? '';
const clientSecret = process.env.TUYA_CLIENT_SECRET ?? '';

async function signedGet<T>(path: string, accessToken?: string): Promise<T> {
  const headers = signTuyaRequest({ clientId, clientSecret, accessToken, method: 'GET', pathWithQuery: path });
  const response = await axios.get(`${baseUrl}${path}`, { headers: headers as unknown as Record<string, string> });
  return response.data as T;
}

interface TuyaEnvelope<T> {
  success: boolean;
  code?: number;
  msg?: string;
  result: T;
}

async function main(): Promise<void> {
  if (!baseUrl || !clientId || !clientSecret) {
    console.error('Missing TUYA_BASE_URL / TUYA_CLIENT_ID / TUYA_CLIENT_SECRET in environment.');
    process.exitCode = 1;
    return;
  }

  console.log(`=== 1. Project token (${baseUrl}) ===`);
  const tokenEnvelope = await signedGet<TuyaEnvelope<{ access_token: string; expire_time: number }>>(
    '/v1.0/token?grant_type=1',
  );
  if (!tokenEnvelope.success) {
    console.log(`❌ ${tokenEnvelope.code}: ${tokenEnvelope.msg}`);
    process.exitCode = 1;
    return;
  }
  console.log('✅ Got project access token.');
  const accessToken = tokenEnvelope.result.access_token;

  console.log(`\n=== 2. Device info (${DEVICE_ID}) ===`);
  const infoEnvelope = await signedGet<TuyaEnvelope<unknown>>(`/v1.0/devices/${DEVICE_ID}`, accessToken);
  if (!infoEnvelope.success) {
    console.log(`❌ ${infoEnvelope.code}: ${infoEnvelope.msg}`);
    console.log('   (This usually means the device is not yet linked to THIS Tuya Cloud project — see below.)');
  } else {
    console.log('✅', JSON.stringify(infoEnvelope.result, null, 2));
  }

  console.log(`\n=== 3. Device status ===`);
  const statusEnvelope = await signedGet<TuyaEnvelope<unknown>>(`/v1.0/devices/${DEVICE_ID}/status`, accessToken);
  if (!statusEnvelope.success) {
    console.log(`❌ ${statusEnvelope.code}: ${statusEnvelope.msg}`);
  } else {
    console.log('✅', JSON.stringify(statusEnvelope.result, null, 2));
  }

  console.log(`\n=== 4. Device functions (real DP schema) ===`);
  const functionsEnvelope = await signedGet<TuyaEnvelope<unknown>>(
    `/v1.0/devices/${DEVICE_ID}/functions`,
    accessToken,
  );
  if (!functionsEnvelope.success) {
    console.log(`❌ ${functionsEnvelope.code}: ${functionsEnvelope.msg}`);
  } else {
    console.log('✅', JSON.stringify(functionsEnvelope.result, null, 2));
  }
}

main().catch((error: unknown) => {
  if (axios.isAxiosError(error)) {
    console.error('❌ Request failed:', error.response?.status, JSON.stringify(error.response?.data));
  } else {
    console.error('❌ Unexpected error:', error);
  }
  process.exitCode = 1;
});
