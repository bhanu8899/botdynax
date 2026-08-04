import { createHash, createHmac } from 'crypto';

/// Implements Tuya's Cloud API request-signing algorithm (the "new
/// signature" scheme documented at
/// https://developer.tuya.com/en/docs/iot/new-singnature — this endpoint
/// path is stable across Tuya API versions and is the one piece of this
/// module you should not need to touch).
///
/// sign = HMAC-SHA256(secret, client_id + [access_token] + t + nonce + stringToSign).toUpperCase()
/// stringToSign = METHOD + "\n" + sha256(body) + "\n" + signedHeaders + "\n" + url(path + query)
export interface TuyaSignedHeaders {
  client_id: string;
  sign: string;
  t: string;
  sign_method: 'HMAC-SHA256';
  access_token?: string;
}

/// Tuya requires query parameters sorted by key (ASCII) in the signed
/// string, and the request must be sent against that same canonical form.
/// Requests whose params happen to already be alphabetical sign correctly
/// by luck; any other ordering fails with "sign invalid". Always route
/// both the signature and the outgoing URL through this.
export function canonicalizeTuyaPath(pathWithQuery: string): string {
  const queryIndex = pathWithQuery.indexOf('?');
  if (queryIndex === -1) return pathWithQuery;

  const path = pathWithQuery.slice(0, queryIndex);
  const query = pathWithQuery.slice(queryIndex + 1);
  if (!query) return path;

  const sorted = query
    .split('&')
    .filter((pair) => pair.length > 0)
    .map((pair) => {
      const eq = pair.indexOf('=');
      return eq === -1 ? ([pair, ''] as const) : ([pair.slice(0, eq), pair.slice(eq + 1)] as const);
    })
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0))
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  return `${path}?${sorted}`;
}

export function signTuyaRequest(params: {
  clientId: string;
  clientSecret: string;
  accessToken?: string;
  method: string;
  /// Path plus query string, e.g. "/v1.0/devices/abc/status".
  pathWithQuery: string;
  body?: string;
}): TuyaSignedHeaders {
  const { clientId, clientSecret, accessToken, method, pathWithQuery, body } = params;

  const t = Date.now().toString();
  const contentHash = createHash('sha256')
    .update(body ?? '')
    .digest('hex');
  const signedHeadersString = '';

  const stringToSign = [
    method.toUpperCase(),
    contentHash,
    signedHeadersString,
    canonicalizeTuyaPath(pathWithQuery),
  ].join('\n');

  const signStr = `${clientId}${accessToken ?? ''}${t}${stringToSign}`;
  const sign = createHmac('sha256', clientSecret).update(signStr).digest('hex').toUpperCase();

  return {
    client_id: clientId,
    sign,
    t,
    sign_method: 'HMAC-SHA256',
    ...(accessToken ? { access_token: accessToken } : {}),
  };
}
