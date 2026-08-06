/**
 * Dumps the device's FULL Tuya v2.0 "thing model" — the complete data-point
 * definition, including private/custom DPs that the v1.x
 * `/specifications` endpoint omits (it only returns the standard
 * instruction set).
 *
 * This is how capabilities like `mop_state` and the `total_error` fault
 * bitmask are discoverable at all.
 *
 * Run with: npx ts-node scripts/dump-thing-model.ts
 */
import { readFileSync, writeFileSync } from 'fs';
import { join } from 'path';

import axios from 'axios';

import { canonicalizeTuyaPath, signTuyaRequest } from '../src/tuya/tuya-signature.util';

const DEVICE_ID = 'd7ae521a982d49fbc4ikal';
const OUT = join(__dirname, '..', 'thing-model.json');

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

interface Property {
  abilityId: number;
  accessMode: string;
  code: string;
  description?: string;
  name?: string;
  typeSpec: { type: string; range?: string[]; maxlen?: number };
}

async function main(): Promise<void> {
  const token = (await req<{ access_token: string }>('/v1.0/token?grant_type=1')).result.access_token;

  const m = await req<{ model: string }>(`/v2.0/cloud/thing/${DEVICE_ID}/model`, token);
  const model = JSON.parse(m.result.model) as { services: Array<{ properties: Property[] }> };
  writeFileSync(OUT, JSON.stringify(model, null, 2), 'utf8');
  console.log(`full model written to ${OUT}`);

  const props = model.services.flatMap((s) => s.properties);
  console.log(`\nTOTAL PROPERTIES: ${props.length}\n`);
  console.log('=== ALL DPs ===');
  for (const p of props) {
    console.log(`  dp${String(p.abilityId).padStart(3)} ${p.accessMode.padEnd(3)} ${p.code.padEnd(28)} ${p.typeSpec.type}`);
  }

  const te = props.find((p) => p.code === 'total_error');
  console.log('\n=== total_error (fault bitmask) ===');
  console.log(JSON.stringify(te, null, 2));

  console.log('\n=== mop / water / tank / dust / error DPs ===');
  for (const p of props) {
    if (!/mop|water|tank|dust|error|fault|box|bucket|clean_box/i.test(p.code)) continue;
    console.log(`\n  ${p.code}  [${p.typeSpec.type}] ${JSON.stringify(p.typeSpec.range ?? '')}`);
    console.log(`    name: ${p.name ?? ''}`);
    console.log(`    desc: ${(p.description ?? '').replace(/\n/g, ' | ')}`);
  }

  // Current live values for those DPs.
  const shadow = await req<{ properties: Array<{ code: string; dp_id: number; value: unknown; type: string }> }>(
    `/v2.0/cloud/thing/${DEVICE_ID}/shadow/properties`,
    token,
  );
  console.log('\n=== CURRENT VALUES (all DPs) ===');
  for (const p of shadow.result.properties) {
    console.log(`  dp${String(p.dp_id).padStart(3)} ${p.code.padEnd(28)} = ${JSON.stringify(p.value)}`);
  }
}

main().catch((e: unknown) => {
  console.error('failed:', e);
  process.exitCode = 1;
});
