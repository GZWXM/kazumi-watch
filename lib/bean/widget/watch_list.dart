import 'package:flutter/material.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/widget/circle_insets.dart';

/// 圆屏专用列表
/// 每一行根据其在屏幕上的实时 Y 坐标动态计算左右内缩，以适配圆形边界
class WatchBandList extends StatefulWidget {
  const WatchBandList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.pitch = 52.0,
    this.headerExtent = 0.0,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  
  /// 行间距 pitch (视觉高 + 间隙)
  final double pitch;
  
  /// 头部偏移量
  final double headerExtent;
  
  /// 滚动控制器
  final ScrollController? controller;

  @override
  State<WatchBandList> createState() => _WatchBandListState();
}

class _WatchBandListState extends State<WatchBandList> {
  late ScrollController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = ScrollController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView.builder(
          controller: _controller,
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            // 计算当前行的顶部 Y 坐标（相对于屏幕原点）
            // 基础起点是 bodyTop (44) + headerExtent
            // 减去滚动偏移量 offset
            final scrollOffset = _controller.hasClients ? _controller.offset : 0.0;
            final yTop = CircleInsets.bodyTop + widget.headerExtent + index * widget.pitch - scrollOffset;
            
            // 获取该 Y 坐标对应的带内缩
            final inset = CircleInsets.bandInset(yTop);
            
            final row = widget.itemBuilder(context, index);
            
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: row,
            );
          },
        );
      },
    );
  }
}

/// 标准列表项
/// 视觉高 44 + 间 8 (pitch 52)
class WatchRow extends StatelessWidget {
  const WatchRow({
    super.key,
    this.icon,
    required this.title,
    this.meta,
    this.onTap,
  });

  final IconData? icon;
  final String title;
  final String? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (meta != null) ...[
              const SizedBox(width: 8),
              Text(
                meta!,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 富媒体列表项（带封面）
/// 高 60 + 间 8 (pitch 68)
class WatchMediaRow extends StatelessWidget {
  const WatchMediaRow({
    super.key,
    required this.coverUrl,
    required this.title,
    this.meta,
    this.onTap,
  });

  final String coverUrl;
  final String title;
  final String? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            // 封面 42x60（用仓库统一的缓存图片层）
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: NetworkImgLayer(
                src: coverUrl,
                width: 42,
                height: 60,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
