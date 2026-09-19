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
    // ⚠️ setSurfaceSize 给的是物理尺寸：dpr=2 时必须给 466，逻辑宽度才是 233。
    // 早先这里给 233 + dpr2 → 逻辑只有 116.5，而 CircleInsets 的常量是按 233 写的，
    // 几何全错位（渲染出来的行宽/内缩都不是真机的样子）。
    tester.view.devicePixelRatio = 2.0;
    await tester.binding.setSurfaceSize(const Size(466, 466));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
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

  testWidgets('诊断：逐行实际宽度 + bandInset 表（临时）', (tester) async {
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
    tester.takeException(); // 这个用例只做诊断，溢出异常先吞掉
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
