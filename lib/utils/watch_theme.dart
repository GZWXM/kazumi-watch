import 'package:flutter/material.dart';

/// 生成适用于 Wear OS 圆屏的主题
/// 基于 base 主题进行覆盖，主要调整字号、图标大小和密度
ThemeData watchTheme(ThemeData base) {
  // 定义统一的行高
  const double lineHeight = 1.3;

  // 辅助函数：创建文本样式
  TextStyle styleOf(TextStyle? baseStyle, double size, FontWeight weight, {Color? color}) {
    return (baseStyle ?? const TextStyle()).copyWith(
      fontSize: size,
      fontWeight: weight,
      height: lineHeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()], // 数字对齐
    );
  }

  final textTheme = base.textTheme.copyWith(
    displaySmall: styleOf(base.textTheme.displaySmall, 22, FontWeight.w700),
    headlineSmall: styleOf(base.textTheme.headlineSmall, 15, FontWeight.w600),
    titleLarge: styleOf(base.textTheme.titleLarge, 15, FontWeight.w600),
    titleMedium: styleOf(base.textTheme.titleMedium, 15, FontWeight.w600),
    bodyLarge: styleOf(base.textTheme.bodyLarge, 13, FontWeight.w500),
    bodyMedium: styleOf(base.textTheme.bodyMedium, 13, FontWeight.w500),
    titleSmall: styleOf(base.textTheme.titleSmall, 11, FontWeight.w400),
    labelLarge: styleOf(base.textTheme.labelLarge, 13, FontWeight.w600),
    labelMedium: styleOf(base.textTheme.labelMedium, 11, FontWeight.w400),
    labelSmall: styleOf(base.textTheme.labelSmall, 10, FontWeight.w400),
  );

  return base.copyWith(
    textTheme: textTheme,
    iconTheme: base.iconTheme.copyWith(size: 20),
    visualDensity: VisualDensity.compact,
    
    // 按钮样式
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    
    // IconButton 尺寸（40×40 触控格）
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
    ),
    
    // Chip 样式
    chipTheme: base.chipTheme.copyWith(
      labelStyle: textTheme.labelMedium,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    
    // ListTile 样式
    listTileTheme: base.listTileTheme.copyWith(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      iconColor: base.colorScheme.onSurfaceVariant,
      textColor: base.colorScheme.onSurface,
    ),
    
    // TabBar 样式 (防止残留)
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: textTheme.labelMedium,
      unselectedLabelStyle: textTheme.labelMedium,
    ),
  );
}
