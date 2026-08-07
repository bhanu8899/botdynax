import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/notifications/local_notifications_provider.dart';
import 'core/storage/local_storage_provider.dart';
import 'core/storage/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final localStorageService = LocalStorageService();
  await localStorageService.init();

  final ProviderContainer container = ProviderContainer(
    overrides: [localStorageServiceProvider.overrideWithValue(localStorageService)],
  );
  // Create the Android channel and ask for permission up front, so the
  // first real alert can actually make a sound instead of being silently
  // dropped while the channel is still being set up.
  await container.read(localNotificationsProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BotDyNaxApp(),
    ),
  );
}
