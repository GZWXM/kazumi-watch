import 'package:flutter/material.dart';

class PlayerContentTabs extends StatelessWidget {
  const PlayerContentTabs({
    super.key,
    required this.controller,
    required this.onEpisodesSelected,
  });

  final TabController controller;
  final VoidCallback onEpisodesSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // watch 布局：2 个页签改为 chips，11dp 字号（吃 watchTheme 的 titleSmall/labelMedium）、高 32，
    // 避免 TabBar 在圆屏上过宽把选集列表挤出可视带。
    final labels = ['选集', '评论'];

    return Material(
      color: colors.surface,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _TabChip(
                    label: labels[i],
                    selected: controller.index == i,
                    theme: theme,
                    onTap: () {
                      if (i == 0) onEpisodesSelected();
                      controller.animateTo(i);
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    // 11dp 字号直接来自 watchTheme 的 titleSmall（11），不再硬编码字号
    final style = (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      color: selected ? colors.onPrimary : colors.onSurfaceVariant,
    );
    return Material(
      color: selected ? colors.primary : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
