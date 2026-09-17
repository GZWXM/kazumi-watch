part of 'search_page.dart';

const _searchSortLabels = {
  'heat': '热度',
  'rank': '排名',
  'score': '评分',
  'match': '匹配',
};

String _sortLabel(String sort) => _searchSortLabels[sort] ?? '热度';

class _SearchSortMenu extends StatelessWidget {
  const _SearchSortMenu({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: '排序方式',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final sort in _searchSortLabels.entries)
          CheckedPopupMenuItem(
              value: sort.key,
              checked: sort.key == value,
              child: Text('按${sort.value}排序')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_sortLabel(value),
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}


class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(children: [
          const LoadingIndicator(size: 40),
          const SizedBox(height: 20),
          Semantics(
              liveRegion: true,
              child: Text('正在搜索番剧',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium)),
        ]));
  }
}
