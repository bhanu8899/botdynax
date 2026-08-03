/// BotDyNax cloud backend endpoints.
///
/// *** REPLACE WITH YOUR REAL DEPLOYED BACKEND URLS FOR STAGING/PRODUCTION ***
/// Points at the companion NestJS backend (see `/backend`) over the dev
/// machine's LAN IP rather than `localhost` — a physical phone's
/// `localhost` is the phone itself, not this PC, so this only works while
/// the phone and PC share the same LAN/Wi-Fi and the PC's IP doesn't
/// change. For web/desktop/emulator builds on this same machine,
/// `localhost` would also work, but the LAN IP works for those too.
abstract final class BackendConfig {
  static const String apiBaseUrl = 'http://10.183.208.239:3000/api/v1';
  static const String robotsWebSocketUrl = 'ws://10.183.208.239:3000/robots';
}
