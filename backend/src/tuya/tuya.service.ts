import { randomUUID } from 'crypto';

import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

import { PrismaService } from '../prisma/prisma.service';
import { TuyaClientService } from './tuya-client.service';
import { decodeSweeperPath } from './tuya-map-decoder';

export interface TuyaDeviceSummary {
  id: string;
  name: string;
  online: boolean;
  productName: string;
  category: string;
}

export interface TuyaDeviceStatusPoint {
  code: string;
  value: unknown;
}

export interface TuyaDeviceFunction {
  code: string;
  type: string;
  values: string;
}

export interface TuyaTimerFunction {
  code: string;
  value: unknown;
}

export interface CreateTuyaTimerParams {
  aliasName: string;
  time: string;
  timezoneId: string;
  loops: string;
  functions: TuyaTimerFunction[];
}

interface TuyaUserTokenResponse {
  access_token: string;
  refresh_token: string;
  expire_time: number;
  uid: string;
}

interface TuyaMapFileEntry {
  id: number;
  time: number;
  extend?: string;
}

@Injectable()
export class TuyaService {
  constructor(
    private readonly client: TuyaClientService,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  /// Builds the URL the app should open in an in-app WebView so the user
  /// can log into their existing Tuya Smart / Smart Life account and
  /// authorize BotDyNax to access their linked devices.
  ///
  /// *** VERIFY THIS PATH AGAINST YOUR TUYA IOT PLATFORM PROJECT ***
  /// Cloud Development projects show the exact "Link Tuya App Account" URL
  /// format under Cloud > (your project) > Devices > Link Tuya App Account
  /// — the query parameters below match Tuya's documented pattern, but
  /// confirm against your project's own panel since it's parameterized by
  /// your project's schema/subscription.
  getAuthUrl(state: string): string {
    const baseUrl = this.config.get<string>('tuya.baseUrl') ?? '';
    const clientId = this.config.get<string>('tuya.clientId') ?? '';
    const schema = this.config.get<string>('tuya.schema') ?? '';
    const redirectUri = this.config.get<string>('tuya.redirectUri') ?? '';

    const params = new URLSearchParams({
      client_id: clientId,
      schema,
      redirect_uri: redirectUri,
      state,
      response_type: 'code',
    });
    return `${baseUrl}/v1.0/iot-03/users/authorized-login-page?${params.toString()}`;
  }

  generateState(): string {
    return randomUUID();
  }

  /// Exchanges the authorization code returned to `redirectUri` for a
  /// linkage to the user's Tuya account (`uid`), and persists it.
  ///
  /// Confirmed against Tuya's official docs (Authentication Method /
  /// OAuth 2.0 Authorization Flow): `GET /v1.0/token?grant_type=2&code=...`,
  /// called unauthenticated (no access_token) — the same calling
  /// convention as the project-token endpoint (grant_type=1) below.
  async linkAccount(botDyNaxUserId: string, code: string): Promise<void> {
    const tokenResponse = await this.client.signedRequest<TuyaUserTokenResponse>({
      method: 'GET',
      path: `/v1.0/token?grant_type=2&code=${encodeURIComponent(code)}`,
    });

    await this.prisma.tuyaLink.upsert({
      where: { userId: botDyNaxUserId },
      update: {
        tuyaUid: tokenResponse.uid,
        accessToken: tokenResponse.access_token,
        refreshToken: tokenResponse.refresh_token,
        expiresAt: new Date(Date.now() + tokenResponse.expire_time * 1000),
      },
      create: {
        userId: botDyNaxUserId,
        tuyaUid: tokenResponse.uid,
        accessToken: tokenResponse.access_token,
        refreshToken: tokenResponse.refresh_token,
        expiresAt: new Date(Date.now() + tokenResponse.expire_time * 1000),
      },
    });
  }

  async unlinkAccount(botDyNaxUserId: string): Promise<void> {
    await this.prisma.tuyaLink.deleteMany({ where: { userId: botDyNaxUserId } });
  }

  async listDevices(botDyNaxUserId: string): Promise<TuyaDeviceSummary[]> {
    const uid = await this.requireTuyaUid(botDyNaxUserId);
    return this.client.request<TuyaDeviceSummary[]>({
      method: 'GET',
      path: `/v1.0/users/${uid}/devices`,
    });
  }

  /// Device-level operations below are scoped by the CALLER (TuyaController
  /// resolves a backend robot id to its `tuyaDeviceId` via
  /// `RobotsService.requireTuyaDeviceId`, which enforces ownership) rather
  /// than requiring a linked Tuya *account* — devices manufactured/OEM'd
  /// directly into this Tuya Cloud project (e.g. the Milagrow iMap Max
  /// W300) are reachable with just the project token, no per-user OAuth
  /// link needed. `listDevices`/the account-link flow above stays in place
  /// for the separate case of a user connecting their own pre-existing
  /// Tuya-ecosystem device.
  /// Reads status from Tuya's v2.0 "thing shadow", NOT the v1.x
  /// `/devices/{id}/status` endpoint.
  ///
  /// This matters a lot: v1.x exposes only the device's *standard
  /// instruction set* — 17 DPs for this robot — and renames some of them
  /// (`switch_go` -> `power_go`, `battery_percentage` -> `electricity_left`).
  /// The v2.0 shadow returns the device's real, complete model: 37 DPs,
  /// including ones v1.x hides entirely — `total_error` (the fault
  /// bitmask), `mop_state`, `water_output`, `sweep_mop_mode`, `mop_life`
  /// and the wash/dry/dust-collection controls.
  ///
  /// Normalised to the same `{code, value}` shape v1.x returned so callers
  /// don't care which endpoint it came from.
  async getDeviceStatus(deviceId: string): Promise<TuyaDeviceStatusPoint[]> {
    const shadow = await this.client.request<{
      properties: Array<{ code: string; value: unknown; dp_id: number; type: string }>;
    }>({
      method: 'GET',
      path: `/v2.0/cloud/thing/${deviceId}/shadow/properties`,
    });
    return (shadow.properties ?? []).map((p) => ({ code: p.code, value: p.value }));
  }

  async getDeviceFunctions(deviceId: string): Promise<TuyaDeviceFunction[]> {
    const result = await this.client.request<{ functions: TuyaDeviceFunction[] }>({
      method: 'GET',
      path: `/v1.0/devices/${deviceId}/functions`,
    });
    return result.functions;
  }

  /// Issues DP writes via the v2.0 "thing shadow" endpoint, NOT the v1.x
  /// `/devices/{id}/commands` endpoint.
  ///
  /// This was a real bug, confirmed live: v1.x's `/commands` only accepts
  /// the device's 10-DP *standard instruction set* and silently rejects
  /// anything from the real v2.0 model with `2008 command or value not
  /// support` — which is every DP the Station/Preferences/Carpet features
  /// added (`manual_dust_collection`, `wash`, `sweep_mop_mode`,
  /// `carpet_clean_prefer`, `auto_dust_collection`, `auto_air`, etc.).
  /// Verified the v2.0 endpoint handles both the original standard DPs
  /// and the v2-only ones identically, including multiple properties in
  /// one call, so this is a full replacement, not a partial one.
  async sendCommands(deviceId: string, commands: TuyaDeviceStatusPoint[]): Promise<void> {
    if (commands.length === 0) {
      throw new BadRequestException('At least one command is required');
    }
    const properties = Object.fromEntries(commands.map((c) => [c.code, c.value]));
    await this.client.request<Record<string, never>>({
      method: 'POST',
      path: `/v2.0/cloud/thing/${deviceId}/shadow/properties/issue`,
      body: { properties: JSON.stringify(properties) },
    });
  }

  /// Device-side scheduling via Tuya's Device Timer service.
  ///
  /// Confirmed live against the real robot (create → list → delete, then
  /// verified the list came back empty). Two things the docs get wrong in
  /// practice for this device:
  ///  - `category` is documented optional but is REQUIRED — omitting it
  ///    produces a misleading "alias_name param is illegal" error that has
  ///    nothing to do with alias_name.
  ///  - `functions[].code` must be the device's real v2.0 DP name
  ///    (`switch_go`), not the v1.x standard-instruction-set alias
  ///    (`power_go`) — the v1 alias is rejected with
  ///    "function is not exists".
  async createTimer(deviceId: string, params: CreateTuyaTimerParams): Promise<string> {
    const result = await this.client.request<{ timer_id?: string; time_id?: string }>({
      method: 'POST',
      path: `/v2.0/cloud/timer/device/${deviceId}`,
      body: {
        alias_name: params.aliasName,
        time: params.time,
        timezone_id: params.timezoneId,
        loops: params.loops,
        category: 'sd',
        functions: params.functions.map((f) => ({ code: f.code, value: f.value })),
      },
    });
    // Tuya's own reference docs disagree on the field name (return-params
    // table says time_id, the sample response says timer_id) — accept
    // either rather than trusting one.
    const timerId = result.timer_id ?? result.time_id;
    if (!timerId) {
      throw new Error('Tuya timer creation succeeded but returned no timer id');
    }
    return timerId;
  }

  async deleteTimer(deviceId: string, timerId: string): Promise<void> {
    await this.client.request<{ success: boolean }>({
      method: 'DELETE',
      path: `/v2.0/cloud/timer/device/${deviceId}/batch?timer_ids=${timerId}`,
    });
  }

  /// Confirmed live via Tuya's API Explorer under Cloud > Sweeping Robot
  /// Open Service > LASER Robot Vacuum for this project. Despite the
  /// `.bin` extension Tuya's `download` endpoint returns for the map file,
  /// its content is plain JSON (`mapData`/`pathData`/`mapAdditional`) — not
  /// a proprietary binary format requiring Tuya's Panel SDK to decode.
  ///
  /// Returns the raw map JSON plus a decoded `path` block (trajectory,
  /// current robot position, derived heading). Tuya publishes a fresh map
  /// snapshot periodically while the robot cleans — the path grows between
  /// snapshots — so re-fetching this drives a live-updating map. Note the
  /// separate `/realtime-map` endpoint returns an empty result for this
  /// device even mid-clean (verified over repeated polls during a
  /// confirmed active run), so these snapshots are the real source.
  async getLatestMap(deviceId: string): Promise<Record<string, unknown>> {
    const list = await this.client.request<{ datas: TuyaMapFileEntry[] }>({
      method: 'GET',
      path: `/v1.0/users/sweepers/file/${deviceId}/list?file_type=pic&page_no=1&page_size=20`,
    });
    if (!list.datas || list.datas.length === 0) {
      throw new NotFoundException('No map has been recorded for this device yet');
    }
    const latest = list.datas.reduce((a, b) => (b.time > a.time ? b : a));

    const download = await this.client.request<{ app_map: string }>({
      method: 'GET',
      path: `/v1.0/users/sweepers/file/${deviceId}/download?id=${latest.id}`,
    });

    // The pre-signed S3 URL requires no Tuya signing — a plain fetch.
    const mapFile = await axios.get<string>(download.app_map, {
      responseType: 'text',
      transformResponse: (data: string) => data,
    });
    const parsed = JSON.parse(mapFile.data) as Record<string, unknown>;

    const mapData = parsed.mapData as
      | { origin?: [number, number]; resolution?: number }
      | undefined;
    const pathData = parsed.pathData as { rawData?: string } | undefined;

    if (mapData?.origin && typeof mapData.resolution === 'number') {
      parsed.path = decodeSweeperPath(pathData?.rawData, mapData.origin, mapData.resolution);
    } else {
      parsed.path = { points: [], robotPosition: null, headingRadians: null };
    }
    parsed.snapshotId = latest.id;
    parsed.snapshotTime = latest.time;

    return parsed;
  }

  private async requireTuyaUid(botDyNaxUserId: string): Promise<string> {
    const link = await this.prisma.tuyaLink.findUnique({ where: { userId: botDyNaxUserId } });
    if (!link) {
      throw new NotFoundException('No linked Tuya account for this user');
    }
    return link.tuyaUid;
  }
}
