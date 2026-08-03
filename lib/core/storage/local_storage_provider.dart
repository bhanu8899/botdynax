import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_storage_service.dart';

/// Overridden in `main.dart` with an already-initialized instance — reading
/// this provider without the override throws deliberately, since the app
/// must never render before local storage is ready.
final Provider<LocalStorageService> localStorageServiceProvider = Provider<LocalStorageService>((Ref ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden in main.dart');
});
