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
    // 手表圆屏：切换栏压到 28~40dp（原 clamp 下限 48dp = 屏高的 21%，
    // 加上视频区后把选集列表挤得几乎没法滑）。手机上 28dp 也够点。
    final height = (MediaQuery.textScalerOf(context).scale(14) * 1.2 + 8)
        .clamp(28.0, 40.0);

    return Material(
      color: colors.surface,
      child: TabBar(
        controller: controller,
        padding: EdgeInsets.zero,
        dividerHeight: 0,
        splashBorderRadius: BorderRadius.zero,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 4,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: theme.textTheme.titleSmall,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        onTap: (index) {
          if (index == 0) onEpisodesSelected();
        },
        tabs: [
          Tab(text: '选集', height: height),
          Tab(text: '评论', height: height),
        ],
      ),
    );
  }
}
