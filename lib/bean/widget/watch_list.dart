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
    this.extentOf,
    this.edgeScale = 0.85,
    this.edgeAlpha = 0.6,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  
  /// 行间距 pitch (视觉高 + 间隙)
  final double pitch;
  
  /// 头部偏移量
  final double headerExtent;
  
  /// 可选：第 index 个 item 的真实高度。
  /// 列表里存在「高度不等于 pitch」的槽位时必须提供（例：首行统计卡 64 + 其余行 52），
  /// 否则 yTop 的等距近似会偏移，这些行的圆屏内缩就会算错。默认全部按 pitch 计算。
  final double Function(int index)? extentOf;

  /// 贴近上下边缘的行缩到多小（1.0 = 不缩）。观感用，对齐 Wear Compose 的
  /// ScalingLazyColumn / TransformingLazyColumn（官方叫 fisheye：边缘缩放 + 淡出）。
  final double edgeScale;

  /// 贴近上下边缘的行淡到多透明（1.0 = 不淡）。
  final double edgeAlpha;

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
            // 默认按等距 pitch 近似；给了 extentOf 就按真实高度累加，
            // 保证「首行高度 ≠ pitch」时，后面每一行的 yTop 仍然准确。
            final extentOf = widget.extentOf;
            var above = index * widget.pitch;
            if (extentOf != null) {
              above = 0;
              for (var k = 0; k < index; k++) {
                above += extentOf(k);
              }
            }
            final yTop = CircleInsets.bodyTop + widget.headerExtent + above - scrollOffset;
            
            // 获取该 Y 坐标对应的带内缩。
            // 夹紧：yTop 落在圆最窄处（甚至屏外，ListView 的 cacheExtent 会构建
            // 视口外的项）时，bandInset 会算出接近半屏的内缩 —— 行被压成一条线，
            // 进而触发 RenderFlex overflow。官方组件对应的是 min/max 夹紧，
            // 这里给"行宽不低于整屏 62%"的下限（可见区内的行根本碰不到这个夹紧）。
            final width = MediaQuery.sizeOf(context).width;
            // 用行的视觉中心（顶 + pitch/2）而不是顶边：行高 52/68，用顶边会让峰值整体偏上。
            final raw = CircleInsets.bandInsetAtCenter(yTop + widget.pitch / 2);
            // 19% 用实测宽度算（真机 233 → 44.3），再压一道 44 的硬上限做双保险：
            // 任何情况下行宽都不低于约 62%，不会被压成一条线。
            final inset = raw.clamp(0.0, width * 0.19 < 44.0 ? width * 0.19 : 44.0);
            
            final row = widget.itemBuilder(context, index);

            // 观感层：越靠近上下边缘的行越小、越淡（官方 ScalingLazyColumn 那套）。
            // 几何层仍由上面的圆弦内缩负责——缩放只做纵深，不会让行顶出圆边。
            var scale = 1.0;
            var alpha = 1.0;
            if (widget.edgeScale < 1.0 || widget.edgeAlpha < 1.0) {
              final half = MediaQuery.sizeOf(context).height / 2;
              final rowCenter = yTop + widget.pitch / 2;
              final flat = half * 0.45; // 中段平区：这一带不缩不淡
              final k = (((rowCenter - half).abs() - flat) / (half - flat)).clamp(0.0, 1.0);
              scale = 1.0 + (widget.edgeScale - 1.0) * k;
              alpha = 1.0 + (widget.edgeAlpha - 1.0) * k;
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: (scale == 1.0 && alpha == 1.0)
                  ? row
                  : Opacity(
                      opacity: alpha,
                      child: Transform.scale(scale: scale, child: row),
                    ),
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
    // 槽位高度必须 = WatchBandList 的 pitch(52 = 视觉高 44 + 间距 8)：缺这 8px 会让
    // 下面每行的 yTop 逐行偏 8px，内缩越算越小、列表越往下越会顶出圆边。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
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
    // 槽位高度必须 = WatchBandList 的 pitch(68 = 视觉高 60 + 间距 8)：缺这 8px 会让
    // 下面每行的 yTop 逐行偏 8px，内缩越算越小、列表越往下越会顶出圆边。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
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
      ),
    );
  }
}
