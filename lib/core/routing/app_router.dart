import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/accessories/accessories_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/register_screen.dart';
import '../../presentation/diagnostics/diagnostics_screen.dart';
import '../../presentation/history/history_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/map/tuya_map_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/auth_state.dart';
import '../../presentation/remote/remote_control_screen.dart';
import '../../presentation/schedule/schedule_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/tuya/tuya_link_screen.dart';
import '../storage/local_storage_provider.dart';
import 'app_routes.dart';
import 'router_refresh_notifier.dart';

const Set<String> _authFlowRoutes = {
  AppRoutes.onboarding,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((Ref ref) {
  final RouterRefreshNotifier refreshNotifier = RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final AuthState authState = ref.read(authControllerProvider);
      final bool isAuthFlowRoute = _authFlowRoutes.contains(state.matchedLocation);

      if (authState.status == AuthStatus.unknown) {
        return null;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        final bool hasSeenOnboarding = ref.read(localStorageServiceProvider).hasSeenOnboarding;
        if (!hasSeenOnboarding) {
          return state.matchedLocation == AppRoutes.onboarding ? null : AppRoutes.onboarding;
        }
        if (state.matchedLocation == AppRoutes.onboarding || !isAuthFlowRoute) {
          return AppRoutes.login;
        }
        return null;
      }

      // authenticated
      if (isAuthFlowRoute) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (BuildContext context, GoRouterState state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (BuildContext context, GoRouterState state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.tuyaLink,
        name: 'tuyaLink',
        builder: (BuildContext context, GoRouterState state) => const TuyaLinkScreen(),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        name: 'diagnostics',
        builder: (BuildContext context, GoRouterState state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.map,
        name: 'map',
        // TuyaMapScreen, not the simulator-oriented MapScreen/MapPainter —
        // TuyaTransport is the active transport, and Tuya's Cloud API only
        // exposes a point-cloud map snapshot, not the richer vector format
        // (room polygons/virtual walls) MapScreen was built for.
        builder: (BuildContext context, GoRouterState state) => const TuyaMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.remoteControl,
        name: 'remoteControl',
        // Manual driving feels like stepping into a control mode, not a new
        // page — a slide-up modal transition reads better here than the
        // default platform push.
        pageBuilder: (BuildContext context, GoRouterState state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const RemoteControlScreen(),
            transitionsBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic))
                    .animate(animation),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.schedule,
        name: 'schedule',
        builder: (BuildContext context, GoRouterState state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        name: 'history',
        builder: (BuildContext context, GoRouterState state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessories,
        name: 'accessories',
        builder: (BuildContext context, GoRouterState state) => const AccessoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (BuildContext context, GoRouterState state) => const NotificationsScreen(),
      ),
    ],
  );
});
