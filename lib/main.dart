import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/services/settings_service.dart';
import 'features/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(ChangeNotifierProvider(create: (_) => SettingsService(prefs), child: const FluentPlayerApp()));
}

class FluentPlayerApp extends StatelessWidget {
  const FluentPlayerApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    ColorScheme lightColorScheme = ColorScheme.fromSeed(seedColor: settings.accentColor, brightness: Brightness.light);
    ColorScheme darkColorScheme = ColorScheme.fromSeed(seedColor: settings.accentColor, brightness: Brightness.dark);
    if (settings.useAmoledDark && settings.themeMode == ThemeMode.dark) {
      darkColorScheme = darkColorScheme.copyWith(surface: Colors.black, background: Colors.black);
    }
    return MaterialApp(
      title: 'Fluent Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(lightColorScheme),
      darkTheme: AppTheme.darkTheme(darkColorScheme),
      themeMode: settings.themeMode,
      home: const HomePage(),
    );
  }
}
