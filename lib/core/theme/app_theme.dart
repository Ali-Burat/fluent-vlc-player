import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  static ThemeData lightTheme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true, colorScheme: colorScheme, brightness: Brightness.light,
    appBarTheme: AppBarTheme(elevation: 0, scrolledUnderElevation: 0, backgroundColor: colorScheme.surface, foregroundColor: colorScheme.onSurface),
    cardTheme: CardTheme(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)), color: colorScheme.surfaceVariant),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: colorScheme.surfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none)),
    navigationBarTheme: NavigationBarThemeData(elevation: 0, backgroundColor: colorScheme.surface, indicatorColor: colorScheme.secondaryContainer),
    dialogTheme: DialogTheme(elevation: 0, backgroundColor: colorScheme.surfaceVariant, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXL))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)))),
    sliderTheme: SliderThemeData(activeTrackColor: colorScheme.primary, inactiveTrackColor: colorScheme.surfaceVariant, thumbColor: colorScheme.primary),
  );

  static ThemeData darkTheme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true, colorScheme: colorScheme, brightness: Brightness.dark,
    appBarTheme: AppBarTheme(elevation: 0, scrolledUnderElevation: 0, backgroundColor: colorScheme.surface, foregroundColor: colorScheme.onSurface),
    cardTheme: CardTheme(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)), color: colorScheme.surfaceVariant),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: colorScheme.surfaceVariant, border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none)),
    navigationBarTheme: NavigationBarThemeData(elevation: 0, backgroundColor: colorScheme.surface, indicatorColor: colorScheme.secondaryContainer),
    dialogTheme: DialogTheme(elevation: 0, backgroundColor: colorScheme.surfaceVariant, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXL))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: colorScheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)))),
    sliderTheme: SliderThemeData(activeTrackColor: colorScheme.primary, inactiveTrackColor: colorScheme.surfaceVariant, thumbColor: colorScheme.primary),
  );
}

class ThemeColors {
  static const List<Color> presetColors = [Colors.blue, Colors.teal, Colors.green, Colors.amber, Colors.orange, Colors.deepOrange, Colors.red, Colors.pink, Colors.purple, Colors.indigo, Colors.cyan, Colors.lime];
  static const List<String> colorNames = ['海洋蓝', '青碧', '翠绿', '琥珀', '橙黄', '深橙', '中国红', '粉红', '紫罗兰', '靛蓝', '天青', '柠檬绿'];
}
