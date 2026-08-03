import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/auth_providers.dart';

/// Bridges Riverpod's [authControllerProvider] into GoRouter's
/// `refreshListenable`, so navigation re-evaluates [GoRouter.redirect]
/// whenever auth state changes (login, logout, session restore).
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}
