import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/watch_list.dart';
import 'package:kazumi/bean/widget/watch_scaffold.dart';
import 'package:kazumi/modules/collect/collect_type.dart';
import 'package:kazumi/modules/history/history_module.dart';
import 'package:kazumi/pages/collect/collect_controller.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/history/history_list_view.dart';
import 'package:kazumi/pages/history/history_record_tile.dart';
import 'package:kazumi/services/player/history_playback_service.dart';
import 'package:kazumi/services/plugin/rule_engine_models.dart'
    show RuleCancelToken;
import 'package:kazumi/utils/device.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.controller});

  final HistoryController controller;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with KazumiDialogOwner {
  bool _editing = false;
  bool _clearing = false;
  final Set<String> _deleting = {};

  HistoryPlaybackService get _playbackService =>
      inject<HistoryPlaybackService>();

  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  /// 圆屏「继续播放」：与 [_HistoryCardState._play] 同一条服务链路。
  Future<void> _play(History history) async {
    if (_editing || _clearing || _deleting.isNotEmpty || dialogs.isRunning) {
      return;
    }
    await dialogs.run((task) async {
      final cancelToken = RuleCancelToken();
      final result = await task.loading(
        message: '获取中',
        onCancel: cancelToken.cancel,
        action: () =>
            _playbackService.open(history, cancelToken: cancelToken),
      );
      switch (result) {
        case HistoryPlaybackReady(:final args):
          task.withContext(
              (context) => context.pushNamed('/video/', arguments: args));
        case HistoryPlaybackUnavailable(:final reason):
          KazumiDialog.showToast(message: reason);
      }
    }, errorMessage: '暂时无法继续播放，请稍后重试');
  }

  Future<void> _deleteHistory(History history) async {
    if (_clearing || _deleting.contains(history.key)) return;
    setState(() => _deleting.add(history.key));
    try {
      await widget.controller.deleteHistory(history);
      if (mounted && widget.controller.histories.isEmpty) {
        setState(() => _editing = false);
      }
    } catch (_) {
      if (mounted) {
        KazumiDialog.showToast(context: context, message: '删除失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(history.key));
    }
  }

  Future<void> _clearHistory() async {
    if (_clearing || _deleting.isNotEmpty) return;
    final confirmed = await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('清空历史记录？'),
        content: Text(
            '将删除全部 ${widget.controller.histories.length} 条观看记录，包括在线和缓存记录。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空全部'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await widget.controller.clearAll();
      if (mounted) setState(() => _editing = false);
    } catch (_) {
      if (mounted) {
        KazumiDialog.showToast(context: context, message: '清空失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  /// 圆屏布局：WatchScaffold + WatchBandList。
  /// 行内缩全部由 WatchBandList 负责，页面层不加水平 Padding。
  /// 行 = N 条记录行（pitch 64 = 视觉 56 + 间隙 8）+ 末尾一行操作行（管理/清空）。
  Widget _buildWatchLayout(BuildContext context, List<History> entries) {
    return WatchScaffold(
      title: '历史记录',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: WatchBandList(
        pitch: 64,
        itemCount: entries.isEmpty ? 1 : entries.length + 1,
        itemBuilder: (context, index) {
          if (entries.isEmpty) {
            return const GeneralEmptyState(
              icon: Icons.history_rounded,
              title: '还没有观看记录',
            );
          }
          if (index == entries.length) {
            return _WatchHistoryActions(
              count: entries.length,
              editing: _editing,
              busy: _clearing || _deleting.isNotEmpty,
              onToggleEditing: () => setState(() => _editing = !_editing),
              onClear: _clearHistory,
            );
          }
          final history = entries[index];
          return _WatchHistoryRow(
            history: history,
            editing: _editing,
            busy: _clearing || _deleting.contains(history.key),
            onPlay: () => _play(history),
            onDelete: () => _deleteHistory(history),
            onDetails: () =>
                context.pushNamed('/info/', arguments: history.bangumiItem),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      final entries = widget.controller.histories.toList();
      return PopScope(
        canPop: !_editing,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _editing) {
            setState(() => _editing = false);
          }
        },
        // 圆屏走 WatchScaffold + WatchBandList（水平内缩只由 WatchBandList 负责）
        child: isRoundWatch(MediaQuery.sizeOf(context))
            ? _buildWatchLayout(context, entries)
            : Scaffold(
          appBar: SysAppBar(
            title: Text('历史记录',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            actions: [
              if (entries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _editing
                      ? FilledButton.tonal(
                          onPressed: _clearing
                              ? null
                              : () => setState(() => _editing = false),
                          child: const Text('完成'),
                        )
                      : IconButton.filledTonal(
                          tooltip: '管理历史记录',
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                ),
                if (_editing)
                  IconButton(
                    tooltip: '清空全部历史记录',
                    onPressed: _clearing || _deleting.isNotEmpty
                        ? null
                        : _clearHistory,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
              ],
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: HistoryListView(
              entries: entries,
              editing: _editing,
              itemBuilder: (history, borderRadius) => _HistoryCard(
                history: history,
                borderRadius: borderRadius,
                editing: _editing,
                busy: _clearing || _deleting.contains(history.key),
                onDelete: () => _deleteHistory(history),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({
    required this.history,
    required this.onDelete,
    required this.editing,
    required this.busy,
    required this.borderRadius,
  });

  final History history;
  final bool editing;
  final bool busy;
  final Future<void> Function() onDelete;
  final BorderRadius borderRadius;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> with KazumiDialogOwner {
  final CollectController _collectController = inject<CollectController>();
  final HistoryPlaybackService _playbackService =
      inject<HistoryPlaybackService>();
  bool _updatingCollect = false;

  Future<void> _play() async {
    if (widget.editing || widget.busy || dialogs.isRunning) return;
    await dialogs.run((task) async {
      final cancelToken = RuleCancelToken();
      final result = await task.loading(
        message: '获取中',
        barrierDismissible: isDesktop(),
        onCancel: cancelToken.cancel,
        action: () =>
            _playbackService.open(widget.history, cancelToken: cancelToken),
      );
      switch (result) {
        case HistoryPlaybackReady(:final args):
          task.withContext(
              (context) => context.pushNamed('/video/', arguments: args));
        case HistoryPlaybackUnavailable(:final reason):
          KazumiDialog.showToast(message: reason);
      }
    }, errorMessage: '暂时无法继续播放，请稍后重试');
  }

  Future<void> _changeCollect(CollectType type) async {
    if (_updatingCollect) return;
    setState(() => _updatingCollect = true);
    try {
      await _collectController.addCollect(widget.history.bangumiItem,
          type: type.value);
    } catch (_) {
      KazumiDialog.showToast(message: '修改收藏状态失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _updatingCollect = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      // getCollectType reads storage, so track the observable list explicitly.
      _collectController.collectibles.length;
      return HistoryRecordTile(
        history: widget.history,
        borderRadius: widget.borderRadius,
        editing: widget.editing,
        busy: widget.busy,
        onPlay: _play,
        onDelete: widget.onDelete,
        onDetails: () =>
            context.pushNamed('/info/', arguments: widget.history.bangumiItem),
        collectType: CollectType.fromValue(
            _collectController.getCollectType(widget.history.bangumiItem)),
        onChangeCollect: _updatingCollect ? null : _changeCollect,
      );
    });
  }
}

/// 圆屏记录行：视觉高 56 + 间距 8 = WatchBandList pitch 64。
/// 信息密度按圆屏压缩：封面 34×48 + 标题单行 + 剧集/时间单行；
/// 点按继续播放，长按进番剧详情，编辑态在行尾出现删除按钮。
class _WatchHistoryRow extends StatelessWidget {
  const _WatchHistoryRow({
    required this.history,
    required this.editing,
    required this.busy,
    required this.onPlay,
    required this.onDelete,
    required this.onDetails,
  });

  final History history;
  final bool editing;
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final title = history.bangumiItem.nameCn.isEmpty
        ? history.bangumiItem.name
        : history.bangumiItem.nameCn;
    final episode = history.lastWatchEpisodeName.isEmpty
        ? '第 ${history.lastWatchEpisode} 话'
        : history.lastWatchEpisodeName;
    final time = TimeOfDay.fromDateTime(history.lastWatchTime.toLocal())
        .format(context);
    final image = history.bangumiItem.images['large'] ?? '';

    // 槽位高度必须 = pitch(64 = 56 + 8)：缺这 8px 会让下面每行的 yTop 逐行偏移，
    // 内缩越算越小、列表越往下越会顶出圆边。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: editing || busy ? null : onPlay,
        onLongPress: editing || busy ? null : onDetails,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: image.isEmpty
                    ? Container(
                        width: 34,
                        height: 48,
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.movie_outlined,
                            size: 18, color: colors.onSurfaceVariant),
                      )
                    : NetworkImgLayer(
                        src: image,
                        width: 34,
                        height: 48,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$episode · $time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (editing) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '删除记录',
                  onPressed: busy ? null : onDelete,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: colors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 圆屏末尾操作行（同 logs_page 的末尾操作行套路）：视觉高 56 + 间距 8 = pitch 64。
/// 「管理」进入编辑态（行尾出现删除按钮），编辑态下多出「清空」；返回键退出编辑态（PopScope）。
class _WatchHistoryActions extends StatelessWidget {
  const _WatchHistoryActions({
    required this.count,
    required this.editing,
    required this.busy,
    required this.onToggleEditing,
    required this.onClear,
  });

  final int count;
  final bool editing;
  final bool busy;
  final VoidCallback onToggleEditing;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Text(
                editing ? '点按行尾按钮删除' : '共 $count 条记录',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: editing ? '完成' : '管理历史记录',
              onPressed: onToggleEditing,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(editing ? Icons.done_rounded : Icons.edit_outlined,
                  size: 18),
            ),
            if (editing)
              IconButton(
                tooltip: '清空全部历史记录',
                onPressed: busy ? null : onClear,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.delete_sweep_outlined,
                    size: 18, color: colors.error),
              ),
          ],
        ),
      ),
    );
  }
}
