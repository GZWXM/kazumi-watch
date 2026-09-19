import 'package:flutter/material.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/modules/my/watch_stats.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

enum MyDestination {
  theme,
  player,
  danmaku,
  rules,
  history,
  downloads,
  sync,
  storage,
  about,
}

// 圆屏上不再使用 28/48 的大曲率，统一收敛到 16
const _tileRadius = BorderRadius.all(Radius.circular(16));

class MySpaceView extends StatelessWidget {
  const MySpaceView({
    super.key,
    required this.stats,
    required this.onOpen,
  });

  final WatchStats stats;
  final ValueChanged<MyDestination> onOpen;

  @override
  Widget build(BuildContext context) {
    // 圆屏单列顺序行：首行为统计卡，其余走 WatchRow
    final rows = <(String, IconData, MyDestination, String?)>[
      (
        '历史记录',
        Icons.history_rounded,
        MyDestination.history,
        stats.watchedBangumiCount == 0
            ? '暂无观看记录'
            : '看过 ${stats.watchedBangumiCount} 部',
      ),
      (
        '离线下载',
        Icons.download_rounded,
        MyDestination.downloads,
        stats.downloadTaskCount == 0 ? '管理离线内容' : '${stats.downloadTaskCount} 集任务',
      ),
      ('同步备份', Icons.cloud_sync_rounded, MyDestination.sync, '跨设备同步数据'),
      ('存储管理', Icons.cleaning_services_rounded, MyDestination.storage, '缓存与日志'),
      ('外观', Icons.palette_rounded, MyDestination.theme, null),
      ('播放', Icons.play_circle_rounded, MyDestination.player, null),
      ('弹幕', Icons.subtitles_rounded, MyDestination.danmaku, null),
      ('关于', Icons.info_outline_rounded, MyDestination.about, null),
    ];

    return WatchBandList(
      key: const PageStorageKey('my-space'),
      pitch: 52,
      // 首行统计卡高 64 ≠ pitch 52：必须报真实高度，否则它下面每一行的内缩都会算偏
      extentOf: (index) => index == 0 ? 64.0 : 52.0,
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        // 首行：观看统计卡（高 64，两列）
        if (index == 0) {
          return _WatchStatsPanel(
            bangumiCount: stats.watchedBangumiCount,
            episodeCount: stats.watchedEpisodeCount,
          );
        }
        final (title, icon, destination, meta) = rows[index - 1];
        return WatchRow(
          icon: icon,
          title: title,
          meta: meta,
          onTap: () => onOpen(destination),
        );
      },
    );
  }

  // 规则设置主色行：保留公开接口（当前无调用方），供将来把「全部设置」收到首行时使用
  static Widget rulesPrimaryRow({
    required BuildContext context,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return _ExpressiveAction(
      color: colors.primary,
      foreground: colors.onPrimary,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(Icons.extension_rounded,
                  size: 20, color: colors.onPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('规则设置',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: colors.onPrimary)),
              ),
              _ArrowCue(color: colors.onPrimary, foreground: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchStatsPanel extends StatelessWidget {
  const _WatchStatsPanel({
    required this.bangumiCount,
    required this.episodeCount,
  });

  final int bangumiCount;
  final int episodeCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: _tileRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: _StatCount(value: bangumiCount, label: '看过番剧')),
          // 保留仓库已有的自绘形状裁剪，只缩小到适配 64 高卡片
          ExcludeSemantics(
            child: ClipPath(
              clipper: const _SpaceShapeClipper(_SpaceShape.sun),
              child: ColoredBox(
                color: colors.tertiaryContainer,
                child: SizedBox.square(
                  dimension: 24,
                  child: Icon(Icons.auto_awesome_rounded,
                      color: colors.onTertiaryContainer, size: 12),
                ),
              ),
            ),
          ),
          Expanded(child: _StatCount(value: episodeCount, label: '观看集数')),
        ],
      ),
    );
  }
}

class _StatCount extends StatelessWidget {
  const _StatCount({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scale large totals without shrinking their labels.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('$value',
              style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class MySettingsButton extends StatelessWidget {
  const MySettingsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '全部设置',
      child: FilledButton.tonalIcon(
        style: StateActionButton.styleOf(context).copyWith(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
          foregroundColor: WidgetStatePropertyAll(colors.onSurface),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.tune_rounded, size: 20),
        label: const Text('设置'),
      ),
    );
  }
}

class _ArrowCue extends StatelessWidget {
  const _ArrowCue({required this.color, required this.foreground});

  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 32,
          height: 24,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.arrow_forward_rounded, color: foreground, size: 14),
        ),
      );
}

enum _SpaceShape { sun, clover }

class _SpaceShapeClipper extends CustomClipper<Path> {
  const _SpaceShapeClipper(this.shape);

  final _SpaceShape shape;
  static final _paths = {
    _SpaceShape.sun: MaterialShapes.sunny.toPath(),
    _SpaceShape.clover: MaterialShapes.clover4Leaf.toPath(),
  };

  @override
  Path getClip(Size size) => _paths[shape]!
      .transform(Matrix4.diagonal3Values(size.width, size.height, 1).storage);

  @override
  bool shouldReclip(_SpaceShapeClipper oldClipper) => oldClipper.shape != shape;
}

class _ExpressiveAction extends StatefulWidget {
  const _ExpressiveAction({
    required this.color,
    required this.foreground,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final Color foreground;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_ExpressiveAction> createState() => _ExpressiveActionState();
}

class _ExpressiveActionState extends State<_ExpressiveAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : Duration(milliseconds: _pressed ? 150 : 300);
    return Semantics(
      button: true,
      child: AnimatedScale(
        scale: _pressed && !reducedMotion ? .97 : 1,
        duration: duration,
        curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: _pressed ? BorderRadius.circular(16) : _tileRadius,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return widget.foreground.withValues(alpha: .10);
                }
                if (states.contains(WidgetState.focused)) {
                  return widget.foreground.withValues(alpha: .12);
                }
                if (states.contains(WidgetState.hovered)) {
                  return widget.foreground.withValues(alpha: .08);
                }
                return null;
              }),
              child: IconTheme.merge(
                data: IconThemeData(color: widget.foreground),
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.foreground,
                      ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
