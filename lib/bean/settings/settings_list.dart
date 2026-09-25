import 'package:flutter/material.dart';

import 'package:kazumi/bean/widget/circle_insets.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/bean/widget/split_list_row.dart';
import 'package:kazumi/utils/device.dart';

enum _TileKind { plain, toggle, radio }

class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.sections,
    this.maxWidth = 1000,
  });

  final List<Widget> sections;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // 圆屏分支：这个外壳被 23 个设置子页共用，必须在圆上自己收窄，否则内容被圆边切。
    // 非圆屏走下面这段原有实现，逐字未动。
    if (isRoundWatch(MediaQuery.sizeOf(context))) {
      return _RoundSettingsList(sections: sections, maxWidth: maxWidth);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: sections.length,
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: sections[index],
        ),
      ),
    );
  }
}

/// 圆屏设置列表：逐行按「该行在屏幕上的真实垂直中心」取圆弦内缩。
///
/// 为什么这里没用 WatchBandList：它的 yTop 是「index × pitch」的线性模型，前提是每个槽位
/// 高度能提前上报（extentOf）。而本类的 sections 是 23 个设置子页各写各的任意 widget——
/// SettingsSection 内部还嵌 SplitListGroup（行里含图标、可换行描述、滑杆、开关），标题与
/// bottomInfo 同样是任意 widget，高度静态算不出来。硬报一个 pitch 会让 yTop 系统性偏大 →
/// 内缩偏小 → 行顶出圆边（正是这轮要修的症状，且偏差随行号累积）。
/// 所以改读 render tree 里的真实位置：不做高度累加、不做任何估算。
///
/// 内缩只有这一个来源：WatchScaffold 明确不加水平 padding（只加 top 44 / bottom），
/// 本列表自身也只保留垂直 padding 12，圆屏下不存在第二处内缩。
class _RoundSettingsList extends StatefulWidget {
  const _RoundSettingsList({required this.sections, required this.maxWidth});

  final List<Widget> sections;
  final double maxWidth;

  @override
  State<_RoundSettingsList> createState() => _RoundSettingsListState();
}

class _RoundSettingsListState extends State<_RoundSettingsList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: widget.sections.length,
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: _RoundSettingsSlot(
            controller: _controller,
            child: widget.sections[index],
          ),
        ),
      ),
    );
  }
}

/// 一个设置分区槽位：内缩只在本层算一次并施加。
class _RoundSettingsSlot extends StatefulWidget {
  const _RoundSettingsSlot({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  State<_RoundSettingsSlot> createState() => _RoundSettingsSlotState();
}

class _RoundSettingsSlotState extends State<_RoundSettingsSlot> {
  final GlobalKey _probeKey = GlobalKey();

  /// 上一次布局后实测的屏幕坐标（顶部 Y、高度）与当时的滚动偏移。
  double _measuredTop = double.nan;
  double _measuredHeight = 0;
  double _measuredOffset = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      // child 只建一次：滚动时只重算内缩，不重建分区内容。
      child: KeyedSubtree(key: _probeKey, child: widget.child),
      builder: (context, child) {
        // 布局完成后读真实位置。必须在 post-frame 阶段读：build 里布局还没发生。
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

        final width = MediaQuery.sizeOf(context).width;
        // 夹紧口径与 WatchBandList 一致（行宽不低于整屏 62%）：视口外/圆最窄处的行
        // 不压成一条线，否则滑杆、开关这类有固定宽度的内容会 RenderFlex overflow。
        final maxInset = width * 0.19 < 44.0 ? width * 0.19 : 44.0;

        var inset = 0.0;
        if (_measuredTop.isFinite && _measuredHeight > 0) {
          // 上次实测之后又滚了多少：内缩跟着滚动实时变，又不必在 build 里读 render tree
          // （布局未跑完时读到的是过期值）。offscreen 的行会算出大内缩并被上面的夹紧兜住。
          final scrolled = widget.controller.hasClients
              ? widget.controller.offset - _measuredOffset
              : 0.0;
          final center = _measuredTop - scrolled + _measuredHeight / 2;
          inset = CircleInsets.bandInsetAtCenter(center).clamp(0.0, maxInset);
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

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.tiles,
    this.title,
    this.bottomInfo,
    this.margin,
  });

  final List<Widget> tiles;
  final Widget? title;
  final Widget? bottomInfo;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionHeader(title: title!),
            ),
          SplitListGroup(children: tiles),
          if (bottomInfo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: DefaultTextStyle.merge(
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                child: bottomInfo!,
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsRadioSection<T> extends StatelessWidget {
  const SettingsRadioSection({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.tiles,
    this.title,
  });

  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final List<Widget> tiles;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<T>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: SettingsSection(title: title, tiles: tiles),
    );
  }
}

Color _disabledOn(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

class _TileLabel extends StatelessWidget {
  const _TileLabel({
    required this.title,
    this.leading,
    this.description,
    this.enabled = true,
  });

  final Widget title;
  final IconData? leading;
  final Widget? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disabled = enabled ? null : _disabledOn(context);
    final foreground = disabled ?? colorScheme.onSurface;
    final secondary = disabled ?? colorScheme.onSurfaceVariant;

    return Row(
      children: [
        if (leading != null) ...[
          Icon(leading, size: 24, color: secondary),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style: textTheme.bodyLarge?.copyWith(color: foreground),
                child: title,
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: textTheme.bodySmall?.copyWith(color: secondary),
                  child: description!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsCategoryTile extends StatelessWidget {
  const SettingsCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      onHighlightChanged: SplitListRow.pressReporterOf(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.leading,
    this.description,
  });

  final Widget title;
  final IconData? leading;
  final Widget? description;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TileLabel(
                  title: title,
                  leading: leading,
                  description: description,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            showValueIndicator: ShowValueIndicator.never,
            padding: EdgeInsets.zero,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class SettingsTile<T> extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.leading,
    this.description,
    this.trailing,
    this.value,
    this.onPressed,
    this.enabled = true,
  })  : _kind = _TileKind.plain,
        onToggle = null,
        initialValue = null,
        radioValue = null;

  /// Row taps pass null to [onToggle]; switch gestures pass the new value.
  const SettingsTile.switchTile({
    super.key,
    required this.title,
    required this.initialValue,
    required this.onToggle,
    this.leading,
    this.description,
    this.enabled = true,
  })  : _kind = _TileKind.toggle,
        trailing = null,
        value = null,
        onPressed = null,
        radioValue = null;

  const SettingsTile.radioTile({
    super.key,
    required this.title,
    required T this.radioValue,
    this.leading,
    this.description,
    this.enabled = true,
  })  : _kind = _TileKind.radio,
        trailing = null,
        value = null,
        onPressed = null,
        onToggle = null,
        initialValue = null;

  final Widget title;

  final IconData? leading;
  final Widget? description;
  final Widget? trailing;
  final Widget? value;
  final void Function(BuildContext context)? onPressed;
  final void Function(bool? value)? onToggle;
  final bool? initialValue;
  final T? radioValue;
  final bool enabled;
  final _TileKind _kind;

  VoidCallback? _tapHandler(BuildContext context) {
    if (!enabled) {
      return null;
    }
    switch (_kind) {
      case _TileKind.plain:
        return onPressed == null ? null : () => onPressed!(context);
      case _TileKind.toggle:
        return onToggle == null ? null : () => onToggle!(null);
      case _TileKind.radio:
        final registry = RadioGroup.maybeOf<T>(context);
        return registry == null ? null : () => registry.onChanged(radioValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secondary =
        enabled ? colorScheme.onSurfaceVariant : _disabledOn(context);

    return InkWell(
      onTap: _tapHandler(context),
      onHighlightChanged: SplitListRow.pressReporterOf(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              Expanded(
                child: _TileLabel(
                  title: title,
                  leading: leading,
                  description: description,
                  enabled: enabled,
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                DefaultTextStyle.merge(
                  style: textTheme.bodyMedium?.copyWith(color: secondary),
                  child: value!,
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme.merge(
                  data: IconThemeData(color: secondary),
                  child: trailing!,
                ),
              ],
              if (_kind == _TileKind.toggle) ...[
                const SizedBox(width: 12),
                Switch(
                  value: initialValue ?? false,
                  onChanged: enabled ? onToggle : null,
                ),
              ],
              if (_kind == _TileKind.radio) ...[
                const SizedBox(width: 12),
                Radio<T>(value: radioValue as T, enabled: enabled),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
