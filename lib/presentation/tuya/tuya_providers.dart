import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/tuya_link_service.dart';
import '../../data/transport/tuya_transport.dart';
import '../providers/auth_providers.dart';

final Provider<TuyaLinkService> tuyaLinkServiceProvider = Provider<TuyaLinkService>((Ref ref) {
  return TuyaLinkService(dio: ref.watch(apiClientProvider).dio);
});

/// Not wired in as the active [robotTransportProvider] yet — that still
/// defaults to [SimulatorTransport] for development. Swapping a real
/// BotDyNax-on-Tuya device in is exactly one line in `robot_providers.dart`:
/// `TuyaTransport(dio: ref.watch(apiClientProvider).dio)`.
final Provider<TuyaTransport> tuyaTransportProvider = Provider<TuyaTransport>((Ref ref) {
  final TuyaTransport transport = TuyaTransport(dio: ref.watch(apiClientProvider).dio);
  ref.onDispose(() {
    unawaited(transport.dispose());
  });
  return transport;
});
