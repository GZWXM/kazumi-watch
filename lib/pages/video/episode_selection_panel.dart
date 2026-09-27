import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/modules/roads/road_module.dart';

class EpisodeSelectionPanel extends StatefulWidget {
  const EpisodeSelectionPanel({
    super.key,
    required this.title,
    required this.roads,
    required this.selectedRoad,
    required this.selectedEpisode,
    required this.onEpisodeSelected,
    required this.downloads,
    this.onDownload,
    this.isOffline = false,
    this.isPlaying = false,
    this.disableAnimations = false,
  });

  final String title;
  final List<Road> roads;
  final int selectedRoad;
  final int selectedEpisode;
  final void Function(int episode, int road) onEpisodeSelected;
  final ValueChanged<int>? onDownload;
  final Map<String, DownloadEpisode> downloads;
  final bool isOffline;
  final bool isPlaying;
  final bool disableAnimations;

  @override
  EpisodeSelectionPanelState createState() => EpisodeSelectionPanelState();
}

class EpisodeSelectionPanelState extends State<EpisodeSelectionPanel> {
  final _scrollController = ScrollController();
  late final _observerController =
      ListObserverController(controller: _scrollController)
        ..cacheJumpIndexOffset = false;
  late int _visibleRoad = widget.selectedRoad;

  // 圆屏：每行 4 个 44×44 选集钮 + 3 个 4dp 间距，外层水平内缩 12
  static const _gridInset = 12.0;
  static const _gridSpacing = 4.0;
  static const _gridCrossCount = 4;

  bool get _canLocate =>
      widget.selectedRoad >= 0 &&
      widget.selectedRoad < widget.roads.length &&
      widget.selectedEpisode > 0 &&
      widget.selectedEpisode <= widget.roads[widget.selectedRoad].data.length;

  // 圆屏固定工具带高度，不随字号缩放（禁用 TextScaler 作用于几何）
  double get _toolbarHeight => 36;

  void _selectRoad(int road) {
    if (_visibleRoad == road) return;
    setState(() => _visibleRoad = road);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> revealCurrentEpisode() async {
    if (!_canLocate) return;
    setState(() => _visibleRoad = widget.selectedRoad);
    // 等待观察者绑定新线路的 sliver 后再定位
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        !_scrollController.hasClients ||
        !_canLocate ||
        _visibleRoad != widget.selectedRoad) {
      return;
    }

    final index = widget.selectedEpisode - 1;
    final toolbarHeight = _toolbarHeight;
    final item = _observerController.observeItem(index: index);
    if (item != null) {
      final top = item.renderObject
          .localToGlobal(Offset.zero, ancestor: item.viewport)
          .dy;
      if (top >= toolbarHeight &&
          top + item.renderObject.size.height <= item.viewport.size.height) {
        return;
      }
    }
    await _observerController.jumpTo(
      index: index,
      offset: (_) => toolbarHeight,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final road = _visibleRoad >= 0 && _visibleRoad < widget.roads.length
        ? widget.roads[_visibleRoad]
        : null;
    final count = road?.data.length ?? 0;

    return LayoutBuilder(builder: (context, constraints) {
      return ListViewObserver(
        controller: _observerController,
        child: Scrollbar(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  // 圆屏核心带固定水平内缩，首行顶 ≥80 由 scaffold bodyTop + 头部高度自然满足
                  padding: EdgeInsets.symmetric(horizontal: _gridInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          widget.title.isEmpty ? '剧集列表' : widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RoadSelector(
                        roads: widget.roads,
                        visibleRoad: _visibleRoad,
                        isOffline: widget.isOffline,
                        onChanged: _selectRoad,
                        disableAnimations: widget.disableAnimations,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _EpisodeToolbar(
                  height: _toolbarHeight,
                  color: colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.isOffline ? '已缓存 · $count 集' : '$count 集',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            tooltip: '定位当前集',
                            onPressed:
                                _canLocate ? revealCurrentEpisode : null,
                            icon: const Icon(Icons.my_location_rounded,
                                size: 18),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        if (!widget.isOffline) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton.filledTonal(
                              tooltip: '缓存剧集',
                              onPressed: count > 0 && widget.onDownload != null
                                  ? () => widget.onDownload!(_visibleRoad)
                                  : null,
                              icon: const Icon(Icons.download_rounded,
                                  size: 18),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (count == 0)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: GeneralEmptyState(
                    icon: Icons.video_library_outlined,
                    title: '这条线路暂无剧集',
                    compact: true,
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    _gridInset,
                    4,
                    _gridInset,
                    12,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridCrossCount,
                      crossAxisSpacing: _gridSpacing,
                      mainAxisSpacing: _gridSpacing,
                      childAspectRatio: 49.25 / 44,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final episode = index + 1;
                        final name =
                            index < road!.identifier.length &&
                                    road.identifier[index].trim().isNotEmpty
                                ? road.identifier[index]
                                : '第$episode集';
                        return _EpisodeRow(
                          key: ValueKey('$_visibleRoad:$episode'),
                          name: name,
                          episode: episode,
                          selected: _visibleRoad == widget.selectedRoad &&
                              episode == widget.selectedEpisode,
                          isPlaying: widget.isPlaying,
                          isOffline: widget.isOffline,
                          download: widget.downloads[road.data[index]],
                          disableAnimations: widget.disableAnimations,
                          onTap: () =>
                              widget.onEpisodeSelected(episode, _visibleRoad),
                        );
                      },
                      childCount: count,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _EpisodeToolbar extends SliverPersistentHeaderDelegate {
  const _EpisodeToolbar({
    required this.height,
    required this.color,
    required this.child,
  });

  final double height;
  final Color color;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      // 即使按钮触控目标小于槽位，也填满 minExtent 以保持吸顶背景
      SizedBox.expand(child: ColoredBox(color: color, child: child));

  @override
  bool shouldRebuild(covariant _EpisodeToolbar oldDelegate) =>
      height != oldDelegate.height ||
      color != oldDelegate.color ||
      child != oldDelegate.child;
}

/// 线路选择：圆屏改为 11dp chips 的横向滚动条带（chips 是内容横向滚动的规范例外）
class _RoadSelector extends StatelessWidget {
  const _RoadSelector({
    required this.roads,
    required this.visibleRoad,
    required this.isOffline,
    required this.onChanged,
    required this.disableAnimations,
  });

  final List<Road> roads;
  final int visibleRoad;
  final bool isOffline;
  final ValueChanged<int> onChanged;
  final bool disableAnimations;

  String _name(int index) => index >= 0 && index < roads.length
      ? (roads[index].name.trim().isEmpty
          ? '线路 ${index + 1}'
          : roads[index].name)
      : '暂无线路';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final canSwitch = roads.length > 1;
    final reduceMotion =
        disableAnimations || MediaQuery.disableAnimationsOf(context);

    if (!canSwitch) {
      return Text(
        isOffline ? '离线观看' : _name(visibleRoad),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: reduceMotion ? const NeverScrollableScrollPhysics() : null,
        child: Row(
          children: [
            for (var i = 0; i < roads.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == roads.length - 1 ? 0 : 4),
                child: ChoiceChip(
                  key: ValueKey('road-option-$i'),
                  selected: i == visibleRoad,
                  onSelected: (_) => onChanged(i),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(_name(i), maxLines: 1),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight:
                        i == visibleRoad ? FontWeight.w700 : FontWeight.w400,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 圆屏选集格：44×44、radius 12、数字 15dp；缓存/播放状态用角标与语义表达
class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    super.key,
    required this.name,
    required this.episode,
    required this.selected,
    required this.isPlaying,
    required this.isOffline,
    required this.disableAnimations,
    required this.onTap,
    this.download,
  });

  final String name;
  final int episode;
  final bool selected;
  final bool isPlaying;
  final bool isOffline;
  final bool disableAnimations;
  final VoidCallback onTap;
  final DownloadEpisode? download;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow>
    with SingleTickerProviderStateMixin {
  late final _press = AnimationController.unbounded(vsync: this);

  bool get _reduceMotion =>
      widget.disableAnimations || MediaQuery.disableAnimationsOf(context);

  void _setPressed(bool pressed) {
    final target = pressed ? 1.0 : 0.0;
    if (_reduceMotion) {
      _press.value = target;
      return;
    }
    _press.animateWith(SpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 500,
        ratio: 0.8,
      ),
      _press.value,
      target,
      _press.velocity,
    ));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = widget.selected ? colors.onPrimary : colors.onSurface;
    final status =
        widget.isOffline ? DownloadStatus.completed : widget.download?.status;
    final downloadLabel = switch (status) {
      DownloadStatus.completed => '已缓存',
      DownloadStatus.downloading => '正在缓存',
      DownloadStatus.failed => '缓存失败',
      DownloadStatus.paused => '缓存已暂停',
      DownloadStatus.pending => '等待缓存',
      DownloadStatus.resolving => '正在解析',
      _ => null,
    };
    final playbackLabel =
        widget.selected ? (widget.isPlaying ? '正在播放' : '当前选集') : '播放';
    final isCached = status == DownloadStatus.completed;

    return Semantics(
      button: true,
      onTap: widget.onTap,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      label: '${widget.name}，$playbackLabel'
          '${downloadLabel == null ? '' : '，$downloadLabel'}',
      child: Tooltip(
        message: '${widget.name} · $playbackLabel'
            '${downloadLabel == null ? '' : ' · $downloadLabel'}',
        excludeFromSemantics: true,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            // 按压缩放反馈在圆屏上提供可达的触控暗示
            final scale = 1.0 - 0.04 * _press.value.clamp(0.0, 1.0);
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Material(
            animationDuration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            color: widget.selected
                ? colors.primary
                : isCached
                    ? colors.secondaryContainer
                    : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              excludeFromSemantics: true,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.focused)) {
                  return foreground.withValues(alpha: 0.1);
                }
                if (states.contains(WidgetState.hovered)) {
                  return foreground.withValues(alpha: 0.08);
                }
                return null;
              }),
              child: ExcludeSemantics(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${widget.episode}',
                        // 数字用 headlineSmall（watch 主题 15dp），tabular figures 保证对齐
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: foreground,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (isCached)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Icon(
                            Icons.download_done_rounded,
                            size: 12,
                            color: widget.selected
                                ? foreground
                                : colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
