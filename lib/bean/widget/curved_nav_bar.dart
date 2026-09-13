import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆形屏幕专用的弧形导航栏（Wear OS 风格）。
///
/// 与 Material 的 [NavigationBar] 不同，这里把图标沿圆的**下缘**排布：
/// 屏幕是圆的，方形栏的两端必然被裁掉，而弧形排布能天然避开圆角区域。
///
/// ⚠️ 几何要点（踩过的坑）：
///   位置必须**锚在容器底部**算，且 y 一律 ≤ 容器高 − itemSize/2。
///   早先的写法是「圆心 + 半径 × sin(angle)」，其中圆心取容器的 h/2：
///   在 menu.dart 给的 `Positioned(bottom:0, height:104)` 槽位里，算出来的
///   y 是 114~146 —— **全部超出容器 → 整条导航栏看不见**。
///   所以这里改成：中心项贴容器底，两侧沿弧上抬（drop = R(1−cos)）。
class CurvedNavBar extends StatelessWidget {
  const CurvedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// (未选中图标, 选中图标, 文字)
  final List<({IconData icon, IconData selectedIcon, String label})> items;

  /// 图标在弧线上的跨度（度）。两侧各留出余量避免贴到圆边。
  static const double _sweepDeg = 104;

  /// 弧所在半径（相对容器宽度）。越大弧越平、两侧越往外。
  /// 0.34 是按 233dp 宽的圆屏调过的：最外侧项刚好落在圆内。
  static const double _arcRadiusFactor = 0.34;

  /// 每个图标格子的边长
  static const double _itemSize = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        const double itemSize = _itemSize;
        final double sweep = _sweepDeg * math.pi / 180;
        final int n = items.length;

        // 弧半径 + 中心项的基准 y（贴容器底，再留 2px 余量）
        final double arcR = w * _arcRadiusFactor;
        final double baseY = h - itemSize / 2 - 2;

        final List<Widget> children = [];
        for (int i = 0; i < n; i++) {
          // 从左到右均分：t ∈ [0,1]，off ∈ [−sweep/2, +sweep/2]
          final double t = n == 1 ? 0.5 : i / (n - 1);
          final double off = (t - 0.5) * sweep;

          final double x = w / 2 + arcR * math.sin(off);
          // 两侧沿弧上抬：中心项最低，最外侧最高
          final double y = baseY - arcR * (1 - math.cos(off));

          final bool sel = i == selectedIndex;
          final it = items[i];

          children.add(Positioned(
            left: x - itemSize / 2,
            top: y - itemSize / 2,
            width: itemSize,
            height: itemSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    sel ? it.selectedIcon : it.icon,
                    size: 18,
                    color: sel ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  if (sel)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        it.label,
                        style: TextStyle(fontSize: 8, color: scheme.primary),
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
          ));
        }

        return SizedBox(
          width: w,
          height: h,
          child: Stack(children: children),
        );
      },
    );
  }
}
