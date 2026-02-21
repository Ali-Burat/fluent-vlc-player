import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/theme/app_theme.dart';
import 'core/services/settings_service.dart';
import 'core/services/vault_service.dart';
import 'shared/providers/app_providers.dart';
import 'features/home/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive本地存储
  await Hive.initFlutter();
  
  // 注册适配器
  // Hive.registerAdapter(SettingsModelAdapter());
  // Hive.registerAdapter(VaultItemAdapter());
  
  // 打开Hive boxes
  await Hive.openBox('settings');
  await Hive.openBox('vault');
  await Hive.openBox('playlists');
  
  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  runApp(
    const ProviderScope(
      child: FluentVLCPlayerApp(),
    ),
  );
}

class FluentVLCPlayerApp extends ConsumerWidget {
  const FluentVLCPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.themeMode;
    
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
        
        return MaterialApp(
          title: 'Fluent VLC Player',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(lightColorScheme),
          darkTheme: AppTheme.darkTheme(darkColorScheme),
          themeMode: themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
