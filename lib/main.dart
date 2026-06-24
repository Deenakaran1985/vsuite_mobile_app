import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'core/providers/document_provider.dart';
import 'core/providers/instance_provider.dart';
import 'core/providers/vmrfdu_provider.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/storage_service.dart';
import 'screens/auth/pin_lock_screen.dart';
import 'screens/auth/vmrfdu_login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/app_selection_screen.dart';
import 'screens/dashboard/chairman_dashboard_screen.dart';
import 'screens/dashboard/vmrfdu_dashboard_screen.dart';
import 'screens/instances/add_instance_screen.dart';
import 'screens/instances/instance_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  try {
    await Firebase.initializeApp();
    await NotificationService().init();
  } catch (_) {
    // Firebase not configured yet — notifications disabled until google-services.json is added
  }
  runApp(const VSuiteApp());
}

class VSuiteApp extends StatelessWidget {
  const VSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final api     = ApiService(storage);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InstanceProvider(storage, api)),
        ChangeNotifierProvider(create: (_) => DocumentProvider(api)),
        ChangeNotifierProvider(create: (_) => VmrfduProvider(storage, api)),
      ],
      child: MaterialApp(
        title: 'VSuite',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: '/',
        routes: {
          // ── Shared ──────────────────────────────────────────────────────
          '/':                 (_) => const SplashScreen(),
          '/select-app':       (_) => const AppSelectionScreen(),
          '/pin-lock':         (_) => const PinLockScreen(destination: '/select-app'),

          // ── VMRFDU hub flow ──────────────────────────────────────────────
          '/vmrfdu-login':     (_) => const VmrfduLoginScreen(),
          '/vmrfdu-dashboard': (_) => const VmrfduDashboardScreen(),

          // ── V-Suite instance flow ────────────────────────────────────────
          '/dashboard':        (_) => const ChairmanDashboardScreen(),
          '/add-instance':     (_) => const AddInstanceScreen(),
          '/manage-instances': (_) => const InstanceManagerScreen(),
        },
      ),
    );
  }
}
