import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:kazumi/pages/my/my_space_view.dart';
import 'package:kazumi/pages/popular/popular_page.dart';

/// 圆屏界面渲染测试：把改过的页面渲成 PNG，供人工看几何（无需真机）。
///
/// 尺寸必须用 **233 逻辑像素**（= 真机 466 物理像素 ÷ dpr 2）：
/// `isRoundWatch(s)` 的条件是 `shortestSide < 300`（lib/utils/device.dart:32），
/// 传 466 会被判成手机，渲出来的根本不是手表分支。
void main() {
  setUpAll(() async {
    // 测试环境默认没有真字体（文字会渲成方块），把仓库里的 MiSans 装上
    final bytes = File('assets/fonts/MiSans-Regular.ttf').readAsBytesSync();
    final loader = FontLoader('MI_Sans_Regular')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  Future<void> pumpWatch(WidgetTester tester, Widget child) async {
    // ⚠️ setSurfaceSize 给的是**逻辑尺寸**（实测：给 466 时 MediaQuery/尺寸全是 466）。
    // 而 CircleInsets.screen 是 233（真机 466 物理 / dpr2）→ 必须给 233，
    // 否则渲染出来的行宽/内缩全是错的（曾把 466 当逻辑用，行宽刷到 442 的假值）。
    // 也不要再叠 devicePixelRatio：两套尺寸一起改会把画布搞成第三种尺寸。
    await tester.binding.setSurfaceSize(const Size(233, 233));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'MI_Sans_Regular',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B6FCF),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: child,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  const stats = WatchStats(
    watchedEpisodeCount: 128,
    watchedBangumiCount: 9,
    downloadTaskCount: 2,
  );

  testWidgets('几何护栏：逐行宽度不低于屏宽 62% + 打印 bandInset 表', (tester) async {
    await pumpWatch(tester, MySpaceView(stats: stats, onOpen: (_) {}));
    final s = tester.getSize(find.byType(MySpaceView));
    debugPrint('[diag] 逻辑尺寸=${s.width}x${s.height}');
    final rows = find.byType(WatchRow);
    for (var i = 0; i < rows.evaluate().length; i++) {
      final r = tester.getSize(rows.at(i));
      debugPrint('[diag] WatchRow#$i width=${r.width.toStringAsFixed(1)}');
    }
    for (var y = 0.0; y <= 300; y += 20) {
      debugPrint('[diag] bandInset(${y.toInt()})='
          '${CircleInsets.bandInset(y).toStringAsFixed(1)}');
    }
    // 夹紧的回归护栏：任何一行都不得窄于屏宽 62%（否则就是又会被压成一条线）
    final rowsFound = rows.evaluate().length;
    for (var i = 0; i < rowsFound; i++) {
      final w = tester.getSize(rows.at(i)).width;
      expect(w, greaterThanOrEqualTo(233 * 0.62),
          reason: 'WatchRow#$i 宽度 $w 过窄，圆弦内缩的夹紧失效了');
    }
    tester.takeException(); // 布局期可能仍有溢出告警，这个用例只保证宽度下限
  });

  testWidgets('我的页：统计卡 + 设置清单（首屏）', (tester) async {
    await pumpWatch(tester, MySpaceView(stats: stats, onOpen: (_) {}));
    await expectLater(find.byType(MySpaceView),
        matchesGoldenFile('goldens/watch_my_space.png'));
  });

  testWidgets('我的页：上滑 80px（看行宽随位置收窄、末行不偏）', (tester) async {
    await pumpWatch(tester, MySpaceView(stats: stats, onOpen: (_) {}));
    await tester.drag(find.byType(MySpaceView), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(MySpaceView),
        matchesGoldenFile('goldens/watch_my_space_scrolled.png'));
  });

  testWidgets('推荐页列表骨架：首位搜索槽位 = pitch 68', (tester) async {
    // 直接用真组件（WatchSearchEntry），不再手搓替身
    Widget mediaSlot(int i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('番剧第 $i 行', style: const TextStyle(fontSize: 12)),
          ),
        );

    await pumpWatch(
      tester,
      WatchBandList(
        pitch: 68,
        itemCount: 6,
        itemBuilder: (context, index) =>
            index == 0 ? const WatchSearchEntry() : mediaSlot(index),
      ),
    );
    await expectLater(find.byType(WatchBandList),
        matchesGoldenFile('goldens/watch_band_list.png'));
  });

  testWidgets('推荐页列表骨架：滚动中（看边缘缩放/淡出）', (tester) async {
    Widget mediaSlot(int i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('番剧第 $i 行', style: const TextStyle(fontSize: 12)),
          ),
        );
    await pumpWatch(
      tester,
      WatchBandList(
        pitch: 68,
        itemCount: 12,
        itemBuilder: (context, index) => mediaSlot(index),
      ),
    );
    await tester.drag(find.byType(WatchBandList), const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(WatchBandList),
        matchesGoldenFile('goldens/watch_band_list_scrolled.png'));
  });
}
