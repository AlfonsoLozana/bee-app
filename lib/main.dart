import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/insulin_provider.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const InsulinTrackerApp());
}

class InsulinTrackerApp extends StatelessWidget {
  const InsulinTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InsulinProvider(),
      child: MaterialApp(
        title: 'InsulinTracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        // Siempre arranca en login; HomeScreen se carga tras auth exitosa
        home: const LoginScreen(),
      ),
    );
  }
}