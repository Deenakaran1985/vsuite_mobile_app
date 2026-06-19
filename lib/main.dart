import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'core/providers/document_provider.dart';
import 'core/providers/instance_provider.dart';
import 'core/services/api_service.dart';
import 'core/services/storage_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/dashboard/chairman_dashboard_screen.dart';
import 'screens/instances/add_instance_screen.dart';
import 'screens/instances/instance_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
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
      ],
      child: MaterialApp(
        title: 'VSuite',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: '/',
        routes: {
          '/':               (_) => const SplashScreen(),
          '/dashboard':      (_) => const ChairmanDashboardScreen(),
          '/add-instance':   (_) => const AddInstanceScreen(),
          '/manage-instances':(_) => const InstanceManagerScreen(),
        },
      ),
    );
  }
}
