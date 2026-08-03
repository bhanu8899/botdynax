import { randomUUID } from 'crypto';

import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

import { PrismaService } from '../prisma/prisma.service';
import { TuyaClientService } from './tuya-client.service';

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
  async getDeviceStatus(deviceId: string): Promise<TuyaDeviceStatusPoint[]> {
    return this.client.request<TuyaDeviceStatusPoint[]>({
      method: 'GET',
      path: `/v1.0/devices/${deviceId}/status`,
    });
  }

  async getDeviceFunctions(deviceId: string): Promise<TuyaDeviceFunction[]> {
    const result = await this.client.request<{ functions: TuyaDeviceFunction[] }>({
      method: 'GET',
      path: `/v1.0/devices/${deviceId}/functions`,
    });
    return result.functions;
  }

  async sendCommands(deviceId: string, commands: TuyaDeviceStatusPoint[]): Promise<void> {
    if (commands.length === 0) {
      throw new BadRequestException('At least one command is required');
    }
    await this.client.request<{ success: boolean }>({
      method: 'POST',
      path: `/v1.0/devices/${deviceId}/commands`,
      body: { commands },
    });
  }

  /// Confirmed live via Tuya's API Explorer under Cloud > Sweeping Robot
  /// Open Service > LASER Robot Vacuum for this project. Despite the
  /// `.bin` extension Tuya's `download` endpoint returns for the map file,
  /// its content is plain JSON (`mapData`/`pathData`/`mapAdditional`) — not
  /// a proprietary binary format requiring Tuya's Panel SDK to decode.
  async getLatestMap(deviceId: string): Promise<unknown> {
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
    return JSON.parse(mapFile.data);
  }

  private async requireTuyaUid(botDyNaxUserId: string): Promise<string> {
    const link = await this.prisma.tuyaLink.findUnique({ where: { userId: botDyNaxUserId } });
    if (!link) {
      throw new NotFoundException('No linked Tuya account for this user');
    }
    return link.tuyaUid;
  }
}
