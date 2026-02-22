import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/theme/app_theme.dart';
import 'core/services/settings_service.dart';
import 'features/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsService(prefs),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // 使用系统动态颜色或自定义颜色
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;
        
        if (lightDynamic != null && darkDynamic != null) {
          // 使用系统Material You颜色
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // 使用自定义颜色
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: settings.accentColor,
            brightness: Brightness.light,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: settings.accentColor,
            brightness: Brightness.dark,
          );
        }
        
        // AMOLED深色模式
        if (settings.useAmoledDark) {
          darkColorScheme = darkColorScheme.copyWith(
            surface: Colors.black,
            background: Colors.black,
          );
        }
        
        return MaterialApp(
          title: 'Fluent Player',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(lightColorScheme),
          darkTheme: AppTheme.darkTheme(darkColorScheme),
          themeMode: settings.themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
