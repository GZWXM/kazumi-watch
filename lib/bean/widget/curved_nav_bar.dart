import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 圆形屏幕专用的弧形导航栏（Wear OS 风格）。
///
/// 与 Material 的 [NavigationBar] 不同，这里把图标沿圆的**下缘**排布：
/// 屏幕是圆的，方形栏的两端必然被裁掉，而弧形排布能天然避开圆角区域。
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

  /// 弧所在的半径（相对屏幕宽度）
  static const double _radiusFactor = 0.40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        // 圆心放在屏幕中心偏上一点，让图标落在下缘的弧线上
        final double radius = w * _radiusFactor;
        final Offset center = Offset(w / 2, h / 2 + w * 0.02);

        const double itemSize = 42;
        final double sweep = _sweepDeg * math.pi / 180;
        final int n = items.length;

        final List<Widget> children = [];
        for (int i = 0; i < n; i++) {
          // 从底部垂直向下开始，左右对称展开
          final double t = n == 1 ? 0.5 : i / (n - 1);
          final double angle = math.pi / 2 + (t - 0.5) * sweep;
          final Offset pos = Offset(
            center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle),
          );
          final bool sel = i == selectedIndex;
          final it = items[i];

          children.add(Positioned(
            left: pos.dx - itemSize / 2,
            top: pos.dy - itemSize / 2,
            width: itemSize,
            height: itemSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(i),
              // 格子给到 42（内容 = 图标 18 + 文字 ~12 = 30，留足余量），
              // 不再靠缩放兜底：FittedBox 会把内容缩过头导致整个导航栏看不见。
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
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          it.label,
                          style: TextStyle(fontSize: 8.5, color: scheme.primary),
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
