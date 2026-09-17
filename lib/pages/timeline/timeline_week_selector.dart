part of 'timeline_page.dart';

class _TimelineWeekSelector extends StatelessWidget {
  const _TimelineWeekSelector({
    required this.counts,
    this.todayIndex,
    this.isLoading = false,
    this.selectedIndex,
    this.onSelected,
  });

  final List<int> counts;
  final int? todayIndex;
  final bool isLoading;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  static double heightFor(TextScaler scaler) =>
      40 + scaler.scale(20) + scaler.scale(16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final size = MediaQuery.sizeOf(context);
    
    if (isRoundWatch(size)) {
      return _buildWatchChips(context, colors, theme);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final minTabWidth = (scaler.scale(14) * 2 + 16).clamp(48.0, 112.0);
      final scrollable = constraints.maxWidth - 8 < minTabWidth * 7;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: TabBar(
            isScrollable: scrollable,
            tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            indicatorAnimation: TabIndicatorAnimation.elastic,
            labelColor: colors.onPrimary,
            unselectedLabelColor: colors.onSurfaceVariant,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            labelStyle: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            overlayColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? colors.primary.withValues(alpha: .08)
                    : null),
            splashBorderRadius: BorderRadius.circular(24),
            tabs: [
              for (var day = 0; day < 7; day++)
                Tab(
                  height: heightFor(scaler) - 8,
                  child: Semantics(
                    label: '星期${_weekdays[day]}'
                        '${day == todayIndex ? '，今天' : ''}'
                        '${isLoading ? '，加载中' : '，${counts[day]}部'}',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: scrollable ? minTabWidth : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(day == todayIndex ? '今天' : '周${_weekdays[day]}'),
                          const SizedBox(height: 4),
                          Text(
                            isLoading ? '—' : '${counts[day]}',
                            style: TextStyle(
                              fontSize: theme.textTheme.labelSmall?.fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildWatchChips(BuildContext context, ColorScheme colors, ThemeData theme) {
    // Horizontal scrolling chips for round watch
    // Height 32, Font 11, Horizontal inset 21 (handled by parent scaffold/padding usually, but here we ensure width fits)
    // The spec says: "y≈60 的横向 chips（7 个、11dp、高 32、水平内缩 21）"
    // Note: WatchScaffold already applies padding. We just render the row.
    
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          final count = counts[index];
          
          return GestureDetector(
            onTap: () => onSelected?.call(index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                '周${_weekdays[index]}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
