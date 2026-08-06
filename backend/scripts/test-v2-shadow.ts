import { readFileSync } from 'fs';
import { join } from 'path';
import axios from 'axios';
import { signTuyaRequest } from '../src/tuya/tuya-signature.util';

const DEVICE_ID = 'd7ae521a982d49fbc4ikal';

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

async function signedGet<T>(path: string, accessToken?: string): Promise<T> {
  const headers = signTuyaRequest({ clientId, clientSecret, accessToken, method: 'GET', pathWithQuery: path });
  const response = await axios.get(`${baseUrl}${path}`, { headers: headers as unknown as Record<string, string> });
  return response.data as T;
}

async function main(): Promise<void> {
  const tokenEnvelope = await signedGet<{ success: boolean; result: { access_token: string } }>('/v1.0/token?grant_type=1');
  const accessToken = tokenEnvelope.result.access_token;

  console.log('=== v2.0 shadow/properties ===');
  const shadow = await signedGet<unknown>(`/v2.0/cloud/thing/${DEVICE_ID}/shadow/properties`, accessToken);
  console.log(JSON.stringify(shadow, null, 2));

  console.log('=== v2.0 device model (schema) ===');
  const model = await signedGet<{ success: boolean; code?: number; msg?: string }>(`/v2.0/cloud/thing/${DEVICE_ID}/model`, accessToken);
  console.log(JSON.stringify({ success: model.success, code: model.code, msg: model.msg }, null, 2));
}
main().catch((e) => console.error('FAILED', axios.isAxiosError(e) ? e.response?.data : e));
