import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆屏几何原语：圆上每行的可用宽度是深度 y 的函数，唯一的几何事实来源。
///
/// 验算（R=116.5、屏 233）：
///   y=24 → 弦 141.6 → 内缩 (233−141.6)/2+6 ≈ 52   （标题带）
///   y=44 → 弦 182.4 → 内缩 ≈ 31                   （工具带）
///   y=60 → 弦 203.8 → 内缩 ≈ 21
///   y=80 → 弦 221.2 → 内缩 ≈ 12                   （核心带，下限 12）
class CircleInsets {
  static const screen = 233.0;
  static const r = 116.5;
  static const m = 6.0;
  static const titleTop = 24.0;
  static const bodyTop = 44.0;

  /// 计算给定 Y 坐标处的弦长（水平宽度）
  static double _chord(double y) {
    final d = (y - r).abs();
    // 如果超出半径范围，弦长为0
    if (d >= r) return 0;
    return 2 * math.sqrt(r * r - d * d);
  }

  /// 计算矩形的单侧内缩值（含呼吸区 m）
  /// 取矩形上下边缘弦长的较小值，确保内容完全在圆内
  static double insetOf(Rect rect) {
    final w = math.min(_chord(rect.top), _chord(rect.bottom));
    // 最小内缩限制为 12，防止过度挤压
    return math.max(12, (screen - w) / 2 + m);
  }

  /// 根据行顶 Y 坐标获取标准带内缩
  /// 使用固定高度 20 的探针矩形来模拟一行内容的垂直跨度
  static double bandInset(double yTop) {
    return insetOf(Rect.fromLTWH(0, yTop, screen, 20));
  }

  /// 以**行中心** Y 为自变量的内缩（对称）。
  /// [bandInset] 是拿 [yTop, yTop+20] 两边缘里较窄的弦算的，于是有效判定位置
  /// 比行中心偏上约 10dp —— 表现为"最大的那行不在正中、而是偏上，且是一片平台"。
  /// 这个版本直接对中心取弦：峰值正好落在屏心，上下对称。
  static double bandInsetAtCenter(double centerY) {
    return math.max(12, (screen - _chord(centerY)) / 2 + m);
  }
}
