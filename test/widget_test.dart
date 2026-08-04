import 'package:botdynax/app.dart';
import 'package:botdynax/core/storage/local_storage_provider.dart';
import 'package:botdynax/core/storage/local_storage_service.dart';
import 'package:botdynax/core/widgets/glass_card.dart';
import 'package:botdynax/domain/entities/user.dart';
import 'package:botdynax/domain/repositories/auth_repository.dart';
import 'package:botdynax/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocalStorageService implements LocalStorageService {
  bool _hasSeenOnboarding = false;
  String _themeModeName = 'system';
  bool _developerMode = false;
  bool _dndEnabled = false;
  int _dndStartMinutes = 22 * 60;
  int _dndEndMinutes = 7 * 60;

  @override
  Future<void> init() async {}

  @override
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  @override
  Future<void> setHasSeenOnboarding(bool value) async {
    _hasSeenOnboarding = value;
  }

  @override
  String get themeModeName => _themeModeName;

  @override
  Future<void> setThemeModeName(String value) async {
    _themeModeName = value;
  }

  @override
  bool get developerMode => _developerMode;

  @override
  Future<void> setDeveloperMode(bool value) async {
    _developerMode = value;
  }

  @override
  bool get dndEnabled => _dndEnabled;

  @override
  Future<void> setDndEnabled(bool value) async {
    _dndEnabled = value;
  }

  @override
  int get dndStartMinutes => _dndStartMinutes;

  @override
  Future<void> setDndStartMinutes(int value) async {
    _dndStartMinutes = value;
  }

  @override
  int get dndEndMinutes => _dndEndMinutes;

  @override
  Future<void> setDndEndMinutes(int value) async {
    _dndEndMinutes = value;
  }

  @override
  bool get isWithinDndWindow {
    if (!_dndEnabled) return false;
    final DateTime now = DateTime.now();
    final int nowMinutes = now.hour * 60 + now.minute;
    if (_dndStartMinutes <= _dndEndMinutes) {
      return nowMinutes >= _dndStartMinutes && nowMinutes < _dndEndMinutes;
    }
    return nowMinutes >= _dndStartMinutes || nowMinutes < _dndEndMinutes;
  }
}

class _FakeAuthRepository implements AuthRepository {
  static const _guestUser = User(id: 'guest-1', email: null, name: 'Guest-abc123');

  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<User> register({required String email, required String password, required String name}) async =>
      _guestUser;

  @override
  Future<User> login({required String email, required String password}) async => _guestUser;

  @override
  Future<User> loginAsGuest() async => _guestUser;

  @override
  Future<User> loginWithGoogle() async => _guestUser;

  @override
  Future<User> loginWithApple() async => _guestUser;

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('onboarding -> guest login -> home dashboard renders with no errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(_FakeLocalStorageService()),
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const BotDyNaxApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Continue as Guest'), findsOneWidget);
    await tester.tap(find.text('Continue as Guest'));
    await tester.pump();
    // Long enough to cover SimulatorTransport.connect()'s 900ms delay plus
    // the resulting status stream emission and rebuild.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);

    // Confirm we've landed on the home dashboard before scrolling further.
    expect(find.text('BotDyNax Vacuum'), findsOneWidget);

    // "Live Map" sits above "Quick Actions" in the dashboard list. Target
    // the hub tile's GlassCard specifically: with the dashboard hub grid,
    // bare find.text('Live Map') can match more than once. A direct drag
    // (rather than scrollUntilVisible, which can leave the target only
    // partially on-screen at the tiny 800x600 test viewport) reliably
    // brings it into a safely tappable area.
    final Finder liveMapTile = find.widgetWithText(GlassCard, 'Live Map');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Navigate into the Live Map screen. Home's RobotIllustration keeps a
    // repeating AnimationController running underneath (it isn't disposed
    // by a push), so from here on use fixed-duration pump()s rather than
    // pumpAndSettle(), which would never resolve.
    await tester.tap(liveMapTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Live Map'), findsWidgets);

    // Exercise the zoom/rotate controls and a room tap.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.rotate_90_degrees_ccw_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // A room tap opens a modal bottom sheet — dismiss it via its barrier
    // before continuing, or it'll silently absorb the next tap.
    await tester.tapAt(const Offset(400, 50));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Open Manual Control from the bottom control panel and exercise the
    // direction pad.
    await tester.tap(find.text('Manual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Remote Control'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Unmount so the Riverpod container (and the simulator's ticker) is
    // disposed before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
