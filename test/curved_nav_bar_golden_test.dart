import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/curved_nav_bar.dart';

/// 弧形导航栏的渲染测试。
///
/// ⚠️ 必须**复刻真机用法**才能起到验收作用：
///   真机是 466×466 圆屏，导航栏放在 `Positioned(bottom:0, height:104)`
///   （见 lib/pages/menu/menu.dart:150-155）。
///   早先这个测试给的是「466 高的整屏」，几何算出来当然好看，
///   但真机那个 104 高的槽位里四项全跑出去了 —— 测试全绿而真机看不见。
///   所以这里照真机的槽位来，出的图才有意义。
void main() {
  testWidgets('curved nav bar renders inside the real 104dp bottom slot',
      (tester) async {
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
          body: Stack(
            children: [
              // 内容区（空着，只为还原真机的层叠关系）
              const Positioned.fill(child: SizedBox.shrink()),
              // ↓ 真机的底部槽位：menu.dart 里就是 height: 104
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 104,
                child: CurvedNavBar(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  items: const [
                    (
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: '推荐'
                    ),
                    (
                      icon: Icons.timeline_outlined,
                      selectedIcon: Icons.timeline,
                      label: '时间表'
                    ),
                    (
                      icon: Icons.favorite_outlined,
                      selectedIcon: Icons.favorite,
                      label: '追番'
                    ),
                    (
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: '我的'
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 截整屏：这样才能看出图标有没有落在圆内 / 有没有被裁
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/curved_nav_bar.png'),
    );
  });
}
