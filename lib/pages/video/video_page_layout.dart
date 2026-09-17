import 'dart:math' as math;

import 'package:flutter/material.dart';
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
      final fillsWindow =
          fullscreen || isPip || constraints.maxWidth > constraints.maxHeight;
      final hasSidePanel = fillsWindow && !isPip && sidePanel != null;
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
                  child: AspectRatio(
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
