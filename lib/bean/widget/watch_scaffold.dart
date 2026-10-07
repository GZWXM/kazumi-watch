import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/curved_nav_bar.dart';

/// Wear OS 页面骨架
/// 替代 AppBar+Scaffold，处理圆屏安全区、标题带渐隐、底部导航保留区
class WatchScaffold extends StatelessWidget {
  const WatchScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.showTitleFade = true,
    this.showBottomFade = true,
  });

  /// 主内容区域（滚动列表等）
  final Widget child;

  /// 标题文本
  final String? title;

  /// 左侧操作按钮（如返回）
  final Widget? leading;

  /// 是否显示标题下方的渐隐遮罩
  final bool showTitleFade;

  /// 是否显示底部的渐隐遮罩
  final bool showBottomFade;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final theme = Theme.of(context);

    // 底部悬浮导航（由 menu.dart 的圆表 shell 通过 WatchNavReserve 透传）：
    // 此时内容铺满整屏、导航栏悬浮其上，WatchScaffold 不再裁掉可视区；
    // 末尾留白交给列表自己的 contentPadding（见 WatchBandList），
    // 这样最后一项能完整滚出而不是停在按钮背后。
    final navReserve = WatchNavReserve.bottomOf(context);
    // 没有悬浮导航时保持原行为：至少 45dp 或系统安全区（独立路由页口径）。
    final bottomInset = navReserve > 0
        ? 0.0
        : (mq.padding.bottom > 0 ? mq.padding.bottom : 45.0);
    
    // 标题带位置 [max(24, padding.top), +20)
    final titleTop = CircleInsets.titleTop;
    final titleHeight = 20.0;
    
    // 构建标题栏
    Widget? titleBar;
    if (title != null || leading != null) {
      titleBar = Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: CircleInsets.bandInset(titleTop)),
        height: titleHeight,
        margin: EdgeInsets.only(top: titleTop),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(width: 40, height: 40, child: leading),
              SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: leading == null ? TextAlign.center : TextAlign.left,
              ),
            ),
          ],
        ),
      );
      
      // 添加渐隐效果
      if (showTitleFade) {
        titleBar = Stack(
          children: [
            titleBar,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                      theme.scaffoldBackgroundColor.withValues(alpha: 1.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    // 主体内容区域 [44, 233-bottomInset)
    // 注意：这里不直接给 child 加 padding，因为 child 内部可能需要全宽滚动，
    // 具体的行内缩由 WatchBandList 或子组件自己通过 CircleInsets 计算。
    // WatchScaffold 主要负责裁剪和背景。
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 内容层
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: CircleInsets.bodyTop, // 44
                bottom: bottomInset,       // 动态
              ),
              child: child,
            ),
          ),
          
          // 标题层 (Pinned)
          if (titleBar != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: titleBar,
            ),
            
          // 底部渐隐层
          if (showBottomFade)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 1.0),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
