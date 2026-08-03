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

  const stringToSign = [method.toUpperCase(), contentHash, signedHeadersString, pathWithQuery].join('\n');

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
