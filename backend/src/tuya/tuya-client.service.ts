import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';

import { canonicalizeTuyaPath, signTuyaRequest } from './tuya-signature.util';

interface TuyaTokenResponse {
  access_token: string;
  refresh_token: string;
  expire_time: number;
  uid?: string;
}

export interface TuyaApiResponse<T> {
  success: boolean;
  code?: number;
  msg?: string;
  result: T;
}

/// Low-level signed HTTP client for Tuya's Cloud (OpenAPI) platform.
///
/// Holds and auto-refreshes the *project-level* access token (client
/// credentials grant) used to authorize business API calls. This project
/// token is separate from a linked end-user's identity (`uid`) — device
/// ownership scoping happens via the `uid` in the request path/body, not
/// via a per-user OAuth token, matching Tuya's Cloud Development model.
@Injectable()
export class TuyaClientService {
  private readonly logger = new Logger(TuyaClientService.name);
  private readonly http: AxiosInstance;

  private projectToken: { accessToken: string; expiresAt: number } | undefined;

  constructor(private readonly config: ConfigService) {
    this.http = axios.create({ baseURL: this.config.get<string>('tuya.baseUrl') });
  }

  private get clientId(): string {
    return this.config.get<string>('tuya.clientId') ?? '';
  }

  private get clientSecret(): string {
    return this.config.get<string>('tuya.clientSecret') ?? '';
  }

  async getProjectToken(): Promise<string> {
    if (this.projectToken && this.projectToken.expiresAt > Date.now() + 60_000) {
      return this.projectToken.accessToken;
    }

    const response = await this.signedRequest<TuyaTokenResponse>({
      method: 'GET',
      path: '/v1.0/token?grant_type=1',
    });

    this.projectToken = {
      accessToken: response.access_token,
      expiresAt: Date.now() + response.expire_time * 1000,
    };
    return this.projectToken.accessToken;
  }

  /// Signed request using the project token (most business API calls).
  async request<T>(params: { method: string; path: string; body?: unknown }): Promise<T> {
    const token = await this.getProjectToken();
    return this.signedRequest<T>({ ...params, accessToken: token });
  }

  /// Signed request with no access token — used only for the project
  /// token endpoint itself and the auth-code exchange.
  async signedRequest<T>(params: {
    method: string;
    path: string;
    body?: unknown;
    accessToken?: string;
  }): Promise<T> {
    const bodyString = params.body !== undefined ? JSON.stringify(params.body) : undefined;

    const headers = signTuyaRequest({
      clientId: this.clientId,
      clientSecret: this.clientSecret,
      accessToken: params.accessToken,
      method: params.method,
      pathWithQuery: params.path,
      body: bodyString,
    });

    const response = await this.http.request<TuyaApiResponse<T>>({
      method: params.method,
      // Must match the canonical (sorted-query) form that was signed.
      url: canonicalizeTuyaPath(params.path),
      data: bodyString,
      headers: { ...headers, 'Content-Type': 'application/json' },
    });

    if (!response.data.success) {
      this.logger.error(`Tuya API error ${response.data.code}: ${response.data.msg}`);
      throw new Error(`Tuya API error: ${response.data.msg ?? 'unknown error'}`);
    }

    return response.data.result;
  }
}
