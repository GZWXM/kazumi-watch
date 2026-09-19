import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/utils/device.dart';

typedef VideoPlayerLayout = ({bool fillsWindow, bool hasSidePanel});

/// Fullscreen fills the available window; rotation belongs to the OS.
class VideoPageLayout extends StatelessWidget {
  const VideoPageLayout({
    super.key,
    required this.fullscreen,
    required this.isPip,
    required this.playerBuilder,
    required this.tabs,
    this.sidePanel,
  });

  final bool fullscreen;
  final bool isPip;
  final Widget Function(BuildContext context, VideoPlayerLayout layout)
      playerBuilder;
  final Widget tabs;
  final Widget? sidePanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 圆表屏不依赖 SafeArea，底部保留区由 shell 注入，圆边由内层组件用 CircleInsets 处理
      final roundWatch =
          isRoundWatch(MediaQuery.sizeOf(context));
      // 圆表恒为满窗：播放页只有一个形态（照腕上哔哩 WristBilibili 的 PlayerActivity——
      // 没有全屏/不全屏之分，就是一整块画面 + 浮层控件）。
      final fillsWindow = fullscreen ||
          isPip ||
          roundWatch ||
          constraints.maxWidth > constraints.maxHeight;
      final hasSidePanel = fillsWindow && !isPip && sidePanel != null;
      // 圆表全屏：只是把 16:9 的黑边条从 40% 屏高放到满高，看着"没区别"。
      // 全屏应当铺满 —— 用 BoxFit.cover 把画面按比例放大裁边填满整块圆屏，
      // 否则方形屏上永远是一条吃不满的横条。
      final watchFill = roundWatch && fillsWindow;
      // 圆的内接 16:9 矩形（四角落在圆周上时最大）：R=116.5 → 宽 ≈203、高 ≈114。
      // 直接铺满会把四角顶出圆外、还要裁掉画面两侧；内接矩形才是"刚好塞进圆里"。
      final inscribedW = 2 * CircleInsets.r / math.sqrt(1 + (9 / 16) * (9 / 16));
      final inscribedH = inscribedW * 9 / 16;
      if (roundWatch) {
        return Stack(
          alignment: Alignment.centerRight,
          children: [
            Center(
              child: SizedBox(
                width: inscribedW,
                height: inscribedH,
                child: Builder(
                    builder: (context) => playerBuilder(
                        context, (fillsWindow: true, hasSidePanel: hasSidePanel))),
              ),
            ),
            if (hasSidePanel) sidePanel!,
          ],
        );
      }
      final content = Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            children: [
              Flexible(
                flex: fillsWindow ? 1 : 0,
                child: SizedBox(
                  // 圆表：视频区最多占屏高 40%（16:9 会吃掉 56%，把下方选集挤到只剩一百多像素）
                  height: fillsWindow
                      ? double.infinity
                      : (roundWatch
                          ? math.min(constraints.maxWidth * 9 / 16,
                              MediaQuery.sizeOf(context).height * 0.40)
                          : null),
                  width: double.infinity,
                  child: watchFill
                      ? FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: 16,
                            height: 9,
                            child: Builder(
                                builder: (context) => playerBuilder(context, (
                                      fillsWindow: fillsWindow,
                                      hasSidePanel: hasSidePanel
                                    ))),
                          ),
                        )
                      : AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Builder(
                              builder: (context) => playerBuilder(context, (
                                    fillsWindow: fillsWindow,
                                    hasSidePanel: hasSidePanel
                                  ))),
                        ),
                ),
              ),
              if (!fillsWindow) Expanded(child: tabs),
            ],
          ),
          if (hasSidePanel) sidePanel!,
        ],
      );
      if (roundWatch) {
        return content;
      }
      return SafeArea(
        top: !fillsWindow,
        bottom: !fillsWindow,
        left: !fillsWindow,
        right: !fillsWindow,
        child: content,
      );
    });
  }
}
