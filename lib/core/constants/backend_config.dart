/// BotDyNax cloud backend endpoints.
///
/// Deployed standalone on Render (see `/backend`, `render.yaml`) — always
/// on, independent of any dev machine. The free-tier web service spins
/// down after inactivity and takes ~30-60s to wake on the next request,
/// which is normal, not a bug.
abstract final class BackendConfig {
  static const String apiBaseUrl = 'https://botdynax-backend.onrender.com/api/v1';
  static const String robotsWebSocketUrl = 'wss://botdynax-backend.onrender.com/robots';
}
