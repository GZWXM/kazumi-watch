import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/curved_nav_bar.dart';

/// 把弧形导航栏渲染成 PNG（466×466 = OPPO Watch X2 Mini 的物理尺寸）。
///
/// 目的：无设备检查弧形排布是否正确（图标是否落在圆内、间距是否均匀、
/// 选中态是否清楚），避免改完只能靠装机肉眼验证。
///
/// 跑法：flutter test --update-goldens test/curved_nav_bar_golden_test.dart
void main() {
  testWidgets('curved nav bar renders on 466x466 round watch', (tester) async {
    // 表盘尺寸（物理像素）
    await tester.binding.setSurfaceSize(const Size(466, 466));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7B6FCF),
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 200,
              child: CurvedNavBar(
                selectedIndex: 0,
                onSelected: (_) {},
                items: const [
                  (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '推荐'),
                  (icon: Icons.timeline_outlined, selectedIcon: Icons.timeline, label: '时间表'),
                  (icon: Icons.favorite_outlined, selectedIcon: Icons.favorite, label: '追番'),
                  (icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: '我的'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CurvedNavBar),
      matchesGoldenFile('goldens/curved_nav_bar.png'),
    );
  });
}
