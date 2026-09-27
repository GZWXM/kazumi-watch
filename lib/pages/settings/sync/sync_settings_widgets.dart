import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/state_presentation.dart';
import 'package:kazumi/utils/device.dart';

class SyncPageBody extends StatelessWidget {
  const SyncPageBody({super.key, required this.children, this.maxWidth = 880});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // 圆屏分支：本组件是 4 个 sync 页共用的内容外壳。
    // 外壳侧 WatchScaffold 只给 top 44 / bottom 45、明确不加水平 padding ⇒ 水平圆弦
    // 内缩只能由本层给一次（页面里其余 Padding 都是卡片内边距，不是内缩）。
    // 宽屏走下面这段原有实现，逐字未动；maxWidth（880/720/640）在 233dp 屏上永远
    // 不生效（可用宽只有 ~170），圆屏分支直接忽略它。
    if (isRoundWatch(MediaQuery.sizeOf(context))) {
      return _RoundSyncBody(children: children);
    }
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆屏 sync 内容外壳：口径与 settings_list.dart 的 `_RoundSettingsList` 一致 ——
/// 不做高度累加/估算，逐块读 render tree 里的真实屏幕坐标，再按该块上下边缘的圆弦取内缩。
///
/// 为什么不用 SettingsList：本外壳的 children 是异构静态块（intro / 服务卡 / 操作按钮 /
/// 反馈条），要保留 SyncPageBody 的 Column + spacing 视觉节奏，而 SettingsList 的
/// sections 之间没有间距。也不能用 WatchBandList：它的 yTop 是「index × pitch」线性模型，
/// 要求每槽位高度可提前上报，而这里的卡片高度随描述文字换行变化，静态算不出来。
///
/// 内缩口径用 [CircleInsets.insetOf]（取矩形上下边缘里较窄的那条弦），不是
/// `bandInsetAtCenter`：本页有 200dp 上下的大卡片，按中心取弦会给它算 12dp 内缩，
/// 而它的上边缘正落在 y≈44 的窄带里（那里只允许 31dp）→ 卡角被圆边切，正是要修的症状。
class _RoundSyncBody extends StatefulWidget {
  const _RoundSyncBody({required this.children});

  final List<Widget> children;

  @override
  State<_RoundSyncBody> createState() => _RoundSyncBodyState();
}

class _RoundSyncBodyState extends State<_RoundSyncBody> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      // 只留垂直间距（8 顶 + 8 底）：底部保留区由 WatchScaffold 的 45 负责，这里不叠。
      // 水平内缩由每个槽位自己给，本层不再给第二处。
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          for (final child in widget.children)
            _RoundSyncSlot(controller: _controller, child: child),
        ],
      ),
    );
  }
}

/// 一个内容块的槽位：内缩只在本层算一次并施加。
class _RoundSyncSlot extends StatefulWidget {
  const _RoundSyncSlot({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  State<_RoundSyncSlot> createState() => _RoundSyncSlotState();
}

class _RoundSyncSlotState extends State<_RoundSyncSlot> {
  final GlobalKey _probeKey = GlobalKey();

  /// 上一次布局后实测的屏幕坐标（顶部 Y、高度）与当时的滚动偏移。
  double _measuredTop = double.nan;
  double _measuredHeight = 0;
  double _measuredOffset = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      // child 只建一次：滚动时只重算内缩，不重建块的内容。
      child: KeyedSubtree(key: _probeKey, child: widget.child),
      builder: (context, child) {
        // 布局完成后读真实位置。必须在 post-frame 阶段读：build 里布局还没发生。
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

        final width = MediaQuery.sizeOf(context).width;
        // 夹紧口径与 SettingsList / WatchBandList 一致：圆最窄处（y=44）只需 31dp
        // （见 circle_insets.dart 的验算），再压会把卡片里的开关行挤成一条线。
        final maxInset = width * 0.19 < 31.0 ? width * 0.19 : 31.0;

        var inset = 0.0;
        if (_measuredTop.isFinite && _measuredHeight > 0) {
          // 上次实测之后又滚了多少：内缩跟着滚动实时变，又不必在 build 里读 render tree
          // （布局未跑完时读到的是过期值）。屏外的块会算出大内缩并被上面的夹紧兜住。
          final scrolled = widget.controller.hasClients
              ? widget.controller.offset - _measuredOffset
              : 0.0;
          final top = _measuredTop - scrolled;
          inset = CircleInsets.insetOf(
            Rect.fromLTWH(0, top, CircleInsets.screen, _measuredHeight),
          ).clamp(0.0, maxInset);
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: child,
        );
      },
    );
  }

  void _measure() {
    if (!mounted) return;
    final box = _probeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final firstMeasure = !_measuredTop.isFinite;
    _measuredTop = box.localToGlobal(Offset.zero).dy;
    _measuredHeight = box.size.height;
    _measuredOffset =
        widget.controller.hasClients ? widget.controller.offset : 0.0;
    // 首帧必然是「未测量 → 内缩 0」，补一帧让内缩生效；之后滚动由控制器的通知驱动，
    // 不再 setState —— 避免「内缩改宽度 → 文字重排改高度 → 再改内缩」的自激循环。
    if (firstMeasure) setState(() {});
  }
}

class SyncPageIntro extends StatelessWidget {
  const SyncPageIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 圆屏：内容盒只有 ~170dp（SyncPageBody 逐块给的），64dp 徽标 + 16dp 间距吃掉
    // 近一半，标题会被压成两行 ⇒ 徽标收 44/22、标题降到 titleMedium、间距 10。
    // 宽屏逐字未动。
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: round ? 2 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StateIconBadge(
            icon: icon,
            size: round ? 44 : 64,
            iconSize: round ? 22 : 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
          ),
          SizedBox(width: round ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title,
                      style: round
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.headlineSmall),
                ),
                const SizedBox(height: 6),
                Text(description,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SyncFeedback extends StatelessWidget {
  const SyncFeedback({
    super.key,
    required this.message,
    this.error = false,
    this.busy = false,
    this.progress,
  });

  final String message;
  final bool error;
  final bool busy;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 圆屏：反馈条跟卡片同宽（~170dp），16dp 内边距把正文压得太窄 ⇒ 收到 10。
    final round = isRoundWatch(MediaQuery.sizeOf(context));
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(round ? 10 : 16),
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error
                      ? Icons.error_outline_rounded
                      : busy
                          ? Icons.sync_rounded
                          : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: error
                      ? colors.onErrorContainer
                      : colors.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: error
                              ? colors.onErrorContainer
                              : colors.onSecondaryContainer)),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}
