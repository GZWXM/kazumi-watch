import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 圆形屏幕专用的弧形导航栏（Wear OS 风格）。
///
/// 几何验算：
/// - 弧心=屏心 (cx, cy)，半径 R=80。
/// - 角度 θ ∈ {-54°, -18°, 18°, 54°} (相对正下方，即 y 轴正向)。
///   x = cx + R*sin(θ), y = cy + R*cos(θ)。
/// - 最外侧格（θ=54°）中心偏移 (64.7, 47.0)，格 44×44；角点到屏心 ≈110.8 < 116.5−5 ✓
/// - 相邻格间距 2·80·sin18° ≈ 49.4 ≥ 44 ✓（触控格不重叠）
///
/// 注意：容器需填满父级 (Positioned.fill)，以便获取正确的中心点。
class CurvedNavBar extends StatelessWidget {
  const CurvedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// (未选中图标, 选中图标, 文字-已废弃但保留结构以防外部引用错误，实际不使用)
  final List<({IconData icon, IconData selectedIcon, String label})> items;

  static const double _radius = 80.0;
  static const double _itemSize = 44.0;
  static const double _iconSize = 22.0;
  
  // 角度列表 (度)
  static const List<double> _anglesDeg = [-54.0, -18.0, 18.0, 54.0];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // menu.dart 用 Positioned.fill 提供全屏约束，约束中心即屏心
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;
        
        // 屏幕中心
        final double cx = w / 2;
        final double cy = h / 2;

        final List<Widget> children = [];
        
        // 确保 items 长度与 angles 匹配，如果不匹配则截断或跳过
        final count = math.min(items.length, _anglesDeg.length);

        for (int i = 0; i < count; i++) {
          final double thetaRad = _anglesDeg[i] * math.pi / 180.0;
          
          // 相对于正下方的角度。
          // 标准数学坐标: x = r cos(theta), y = r sin(theta).
          // 这里定义: theta=0 为正下方 (y positive in screen coords? No, screen y goes down).
          // 屏幕坐标系: x right, y down.
          // 正下方意味着 x=cx, y=cy+R.
          // 公式: x = cx + R * sin(theta), y = cy + R * cos(theta).
          // 当 theta=0: x=cx, y=cy+R (Bottom). Correct.
          // 当 theta=-54: x < cx, y < cy+R (Left-Bottom). Correct.
          // 当 theta=54: x > cx, y < cy+R (Right-Bottom). Correct.
          
          final double x = cx + _radius * math.sin(thetaRad);
          final double y = cy + _radius * math.cos(thetaRad);

          final bool sel = i == selectedIndex;
          final it = items[i];

          // 背景色
          final Color bgColor;
          final Color iconColor;

          if (sel) {
            bgColor = scheme.primary;
            iconColor = scheme.onPrimary;
          } else {
            bgColor = scheme.surfaceContainer.withValues(alpha: 0.85);
            iconColor = scheme.onSurfaceVariant.withValues(alpha: 0.6);
          }

          children.add(Positioned(
            left: x - _itemSize / 2,
            top: y - _itemSize / 2,
            width: _itemSize,
            height: _itemSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(i),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                ),
                child: Center(
                  child: Icon(
                    sel ? it.selectedIcon : it.icon,
                    size: _iconSize,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ));
        }

        // Stack 默认不拦截空白区域的命中测试，除非子组件有 opaque hit test
        // 这里的 GestureDetector 是 opaque 的，只拦截圆圈区域
        // 其他部分穿透到下面的列表
        return Stack(
          children: children,
        );
      },
    );
  }
}
