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
  
  // 初始化SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsService(prefs),
      child: const FluentPlayerApp(),
    ),
  );
}

class FluentPlayerApp extends StatelessWidget {
  const FluentPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;
        
        if (lightDynamic != null && darkDynamic != null && settings.useMaterialYou) {
          // 使用Material You动态颜色
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // 使用自定义主题颜色
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
        if (settings.useAmoledDark && settings.themeMode == ThemeMode.dark) {
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
