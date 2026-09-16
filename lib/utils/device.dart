import 'dart:io';

import 'package:flutter/material.dart';

Future<bool> isLowResolution() async {
  if (Platform.isMacOS) {
    return false;
  }
  final screenInfo = await getScreenInfo();
  return screenInfo['height']! / screenInfo['ratio']! < 900;
}

Future<Map<String, double>> getScreenInfo() async {
  final mediaQuery = MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.views.first,
  );
  final screenSize =
      WidgetsBinding.instance.platformDispatcher.displays.first.size;
  return {
    'width': screenSize.width,
    'height': screenSize.height,
    'ratio': mediaQuery.devicePixelRatio,
  };
}

bool isDesktop() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// 统一设备判定：是否为圆形手表屏幕
/// 短边 < 300dp 且宽高差在 12% 以内视为圆表
bool isRoundWatch(Size s) =>
    s.shortestSide < 300 && (s.width - s.height).abs() <= s.width * 0.12;
