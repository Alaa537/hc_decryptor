import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const HCApp(),
    ),
  );
}

class HCApp extends StatelessWidget {
  const HCApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HC Decryptor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
