export interface AppConfig {
  port: number;
  jwt: {
    accessSecret: string;
    accessExpiresIn: string;
    refreshSecret: string;
    refreshExpiresInDays: number;
  };
  mqtt: {
    url: string | undefined;
  };
  tuya: {
    baseUrl: string;
    clientId: string;
    clientSecret: string;
    schema: string;
    redirectUri: string;
  };
}

export default (): AppConfig => ({
  port: parseInt(process.env.PORT ?? '3000', 10),
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? 'dev-access-secret-change-me',
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN ?? '15m',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? 'dev-refresh-secret-change-me',
    refreshExpiresInDays: parseInt(process.env.JWT_REFRESH_EXPIRES_IN_DAYS ?? '30', 10),
  },
  mqtt: {
    // Undefined (not defaulted to localhost) on purpose — see
    // MqttBridgeService.onModuleInit for why that matters for cloud deploys.
    url: process.env.MQTT_URL,
  },
  tuya: {
    // *** REPLACE WITH YOUR REAL TUYA IOT PLATFORM CLOUD PROJECT VALUES ***
    // Data-center base URL depends on where your Tuya Cloud Project was
    // created (e.g. https://openapi.tuyaus.com, https://openapi.tuyaeu.com,
    // https://openapi.tuyain.com, https://openapi.tuyacn.com).
    baseUrl: process.env.TUYA_BASE_URL ?? 'https://openapi.tuyaus.com',
    clientId: process.env.TUYA_CLIENT_ID ?? '',
    clientSecret: process.env.TUYA_CLIENT_SECRET ?? '',
    // The linked "App" schema id for your Cloud Project's "Link Tuya App
    // Account" configuration (visible in the Tuya IoT Platform under
    // Cloud > your project > Devices > Link Tuya App Account).
    schema: process.env.TUYA_SCHEMA ?? '',
    redirectUri: process.env.TUYA_REDIRECT_URI ?? 'botdynax://tuya-callback',
  },
});
